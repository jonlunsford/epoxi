defmodule Epoxi.Queue.Durable do
  @moduledoc """
  A durable queue implementation using ETS and DETS for hybrid in-memory/persistent storage.

  This GenServer implements a queue with the following properties:
  - Fast in-memory access via ETS ordered_set tables
  - Periodic persistence to disk via DETS tables
  - Automatic recovery on restart
  - Configurable synchronization intervals

  ## Usage

      # Start a durable queue
      {:ok, pid} = Epoxi.Queue.Durable.start_link(name: :mail_queue)

      # Enqueue a message
      Epoxi.Queue.Durable.enqueue(:mail_queue, email)

      # Dequeue a message
      {:ok, email} = Epoxi.Queue.Durable.dequeue(:mail_queue)
  """

  use GenServer
  require Logger

  @default_sync_interval 5_000
  @default_table_dir "priv/queues"

  # Client API

  @doc """
  Starts a durable queue process.

  ## Options

  * `:name` - The name to register the queue (required)
  * `:sync_interval` - Milliseconds between syncs to disk (default: `5_000`)
  * `:table_dir` - Directory for DETS files (default: `"priv/queues"`)
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Adds a message to the queue.

  Messages are stored with a priority (default 0), timestamp, and unique ID
  to ensure proper ordering even after restarts.

  ## Options

  * `:priority` - Priority of the message (lower is higher priority, default: `0`)
  """
  @spec enqueue(GenServer.server(), any(), Keyword.t()) :: :ok
  def enqueue(queue, message, opts \\ []) do
    priority = Keyword.get(opts, :priority, 0)
    GenServer.call(via_tuple(queue), {:enqueue, message, priority})
  end

  @doc """
  Retrieves and removes the next message from the queue.

  Returns `{:ok, message}` if a message is available, or `:empty` if the queue is empty.
  """
  @spec dequeue(GenServer.server()) :: {:ok, any()} | :empty
  def dequeue(queue) do
    GenServer.call(via_tuple(queue), :dequeue)
  end

  @doc """
  Retrieves but does not remove the next message from the queue.

  Returns `{:ok, message}` if a message is available, or `:empty` if the queue is empty.
  """
  @spec peek(GenServer.server()) :: {:ok, any()} | :empty
  def peek(queue) do
    GenServer.call(via_tuple(queue), :peek)
  end

  @doc """
  Returns the number of messages in the queue.
  """
  @spec length(GenServer.server()) :: non_neg_integer()
  def length(queue) do
    GenServer.call(via_tuple(queue), :length)
  end

  @doc """
  Removes all messages from the queue.
  """
  @spec flush(GenServer.server()) :: :ok
  def flush(queue) do
    GenServer.call(via_tuple(queue), :flush)
  end

  @doc """
  Forces an immediate sync of the ETS table to the DETS table.

  This is automatically called periodically based on the `:sync_interval` option,
  but can be called manually for immediate durability.
  """
  @spec sync(GenServer.server()) :: :ok
  def sync(queue) do
    GenServer.call(via_tuple(queue), :sync)
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    sync_interval = Keyword.get(opts, :sync_interval, @default_sync_interval)
    table_dir = Keyword.get(opts, :table_dir, @default_table_dir)

    ets_table = String.to_atom("#{name}_ets")
    dets_table = String.to_atom("#{name}_dets")

    File.mkdir_p!(table_dir)

    :ets.new(ets_table, [:ordered_set, :protected, :named_table])

    dets_path = Path.join(table_dir, "#{name}.dets")

    case :dets.open_file(dets_table,
           file: String.to_charlist(dets_path),
           type: :ordered_set,
           repair: true
         ) do
      {:ok, ^dets_table} ->
        restore_from_dets(ets_table, dets_table)

        Process.send_after(self(), :sync, sync_interval)

        {:ok, dets_table}

      {:error, reason} ->
        Logger.error("Failed to open DETS table #{dets_path}: #{inspect(reason)}")
        {:error, reason}
    end

    state = %{
      name: name,
      ets_table: ets_table,
      dets_table: dets_table,
      sync_interval: sync_interval,
      table_dir: table_dir,
      stats: %{enqueued: 0, dequeued: 0, last_sync: nil}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:enqueue, message, priority}, _from, state) do
    timestamp = System.system_time(:microsecond)
    id = System.unique_integer([:positive, :monotonic])
    key = {priority, timestamp, id}

    :ets.insert(state.ets_table, {key, message})

    updated_stats = Map.update!(state.stats, :enqueued, &(&1 + 1))

    {:reply, :ok, %{state | stats: updated_stats}}
  end

  @impl true
  def handle_call(:dequeue, _from, state) do
    case :ets.first(state.ets_table) do
      :"$end_of_table" ->
        {:reply, :empty, state}

      key ->
        [{^key, message}] = :ets.lookup(state.ets_table, key)
        :ets.delete(state.ets_table, key)

        updated_stats = Map.update!(state.stats, :dequeued, &(&1 + 1))

        {:reply, {:ok, message}, %{state | stats: updated_stats}}
    end
  end

  @impl true
  def handle_call(:peek, _from, state) do
    case :ets.first(state.ets_table) do
      :"$end_of_table" ->
        {:reply, :empty, state}

      key ->
        [{^key, message}] = :ets.lookup(state.ets_table, key)
        {:reply, {:ok, message}, state}
    end
  end

  @impl true
  def handle_call(:length, _from, state) do
    count = :ets.info(state.ets_table, :size)
    {:reply, count, state}
  end

  @impl true
  def handle_call(:flush, _from, state) do
    :ets.delete_all_objects(state.ets_table)

    :dets.delete_all_objects(state.dets_table)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:sync, _from, state) do
    sync_to_dets(state)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:sync, state) do
    sync_to_dets(state)

    Process.send_after(self(), :sync, state.sync_interval)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    sync_to_dets(state)
    :dets.close(state.dets_table)

    :ok
  end

  defp via_tuple(name) when is_atom(name), do: name
  defp via_tuple(name), do: {:via, Registry, {Epoxi.Queue.Registry, name}}

  defp sync_to_dets(state) do
    # Copy all data from ETS to DETS
    :dets.delete_all_objects(state.dets_table)

    :ets.foldl(
      fn item, _ -> :dets.insert(state.dets_table, item) end,
      nil,
      state.ets_table
    )

    :dets.sync(state.dets_table)

    :telemetry.execute(
      [:epoxi, :queue, :sync],
      %{count: :ets.info(state.ets_table, :size)},
      %{queue: state.name}
    )

    state.stats
  end

  defp restore_from_dets(ets_table, dets_table) do
    :dets.foldl(
      fn item, _ -> :ets.insert(ets_table, item) end,
      nil,
      dets_table
    )
  end
end

