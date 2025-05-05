defmodule Epoxi.Queue do
  @moduledoc """
  A durable queue implementation using ETS and DETS for hybrid in-memory/persistent storage.

  This GenServer implements a queue with the following properties:
  - Fast in-memory access via ETS ordered_set tables
  - Periodic persistence to disk via DETS tables
  - Automatic recovery on restart
  - Configurable synchronization intervals

  ## Usage

      # Start a durable queue
      {:ok, pid} = Epoxi.Queue.start_link(name: :mail_queue)

      # Enqueue a message
      Epoxi.Queue.enqueue(:mail_queue, email)

      # Dequeue a message
      {:ok, email} = Epoxi.Queue.dequeue(:mail_queue)
  """

  use GenServer
  require Logger

  @default_sync_interval 5_000
  @default_table_dir "priv/queues"

  @type queue_name :: atom() | {atom(), atom(), term()}
  @type queue_options :: [
          name: queue_name(),
          sync_interval: pos_integer(),
          table_dir: String.t()
        ]
  @type enqueue_options :: [priority: integer()]

  @doc """
  Starts a durable queue process.

  ## Options

  * `:name` - The name to register the queue (required)
  * `:sync_interval` - Milliseconds between syncs to disk (default: `#{@default_sync_interval}`)
  * `:table_dir` - Directory for DETS files (default: `"#{@default_table_dir}"`)
  """
  @spec start_link(queue_options()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  @doc """
  Adds many messages to the queue, async.

  ## Options
  * `:priority` - Priority of all messages (lower is higher priority, default: `0`)
  """
  @spec enqueue_many(atom(), [any()], enqueue_options()) :: :ok
  def enqueue_many(name, messages, opts \\ []) do
    priority = Keyword.get(opts, :priority, 0)
    registered_name = via_tuple(name)

    Enum.each(messages, fn message ->
      GenServer.cast(registered_name, {:enqueue, message, priority})
    end)
  end

  @doc """
  Adds a message to the queue.

  Messages are stored with a priority (default 0), timestamp, and unique ID
  to ensure proper ordering even after restarts.

  ## Options

  * `:priority` - Priority of the message (lower is higher priority, default: `0`)
  """
  @spec enqueue(atom(), any(), enqueue_options()) :: :ok
  def enqueue(name, message, opts \\ []) do
    priority = Keyword.get(opts, :priority, 0)
    registered_name = via_tuple(name)
    GenServer.call(registered_name, {:enqueue, message, priority})
  end

  @doc """
  Retrieves and removes the next message from the queue.

  Returns `{:ok, message}` if a message is available, or `:empty` if the queue is empty.
  """
  @spec dequeue(atom()) :: {:ok, any()} | :empty
  def dequeue(name) do
    registered_name = via_tuple(name)
    GenServer.call(registered_name, :dequeue)
  end

  @doc """
  Retrieves but does not remove the next message from the queue.

  Returns `{:ok, message}` if a message is available, or `:empty` if the queue is empty.
  """
  @spec peek(atom()) :: {:ok, any()} | :empty
  def peek(name) do
    registered_name = via_tuple(name)
    GenServer.call(registered_name, :peek)
  end

  @doc """
  Returns the number of messages in the queue.
  """
  @spec length(atom()) :: non_neg_integer()
  def length(name) do
    registered_name = via_tuple(name)
    GenServer.call(registered_name, :length)
  end

  @doc """
  Removes all messages from the queue.
  """
  @spec flush(atom()) :: :ok
  def flush(name) do
    registered_name = via_tuple(name)
    GenServer.call(registered_name, :flush)
  end

  @doc """
  Forces an immediate sync of the ETS table to the DETS table.

  This is automatically called periodically based on the `:sync_interval` option,
  but can be called manually for immediate durability.
  """
  @spec sync(atom()) :: :ok
  def sync(name) do
    registered_name = via_tuple(name)
    GenServer.call(registered_name, :sync)
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    sync_interval = Keyword.get(opts, :sync_interval, @default_sync_interval)
    table_dir = Keyword.get(opts, :table_dir, @default_table_dir)
    ets_table_name = table_name(name, "ets")
    dets_table_name = table_name(name, "dets")
    dets_path = Path.join(table_dir, "#{name}.dets")

    with :ok <- create_table_dir(table_dir),
         {:ok, dets_ref} <- open_dets_table(dets_path, dets_table_name),
         {:ok, ets_ref} <- create_ets_table(ets_table_name),
         :ok <- load_dets_to_ets(dets_ref, ets_ref) do
      schedule_sync(sync_interval)

      state = %{
        name: name,
        ets_table: ets_ref,
        dets_table: dets_ref,
        sync_interval: sync_interval,
        table_dir: table_dir,
        stats: %{enqueued: 0, dequeued: 0, last_sync: nil}
      }

      {:ok, state}
    else
      {:error, reason} ->
        Logger.error("Failed to initialize queue #{inspect(name)}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:enqueue, message, priority}, _from, state) do
    insert(state.ets_table, message, priority)

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
    updated_state = do_sync(state)
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_cast({:enqueue, messages, priority}, state) when is_list(messages) do
    insert(state.ets_table, messages, priority)

    count = Kernel.length(messages)

    updated_stats = Map.update!(state.stats, :enqueued, &(&1 + count))

    {:noreply, %{state | stats: updated_stats}}
  end

  @impl true
  def handle_cast({:enqueue, message, priority}, state) do
    insert(state.ets_table, message, priority)

    updated_stats = Map.update!(state.stats, :enqueued, &(&1 + 1))

    {:noreply, %{state | stats: updated_stats}}
  end

  @impl true
  def handle_info(:sync, state) do
    updated_state = do_sync(state)
    schedule_sync(state.sync_interval)
    {:noreply, updated_state}
  end

  @impl true
  def terminate(_reason, state) do
    do_sync(state)

    :dets.close(state.dets_table)

    :ok
  end

  defp insert(ets_table, messages, priority) when is_list(messages) do
    messages
    |> Enum.map(fn message ->
      insert(ets_table, message, priority)
    end)
  end

  defp insert(ets_table, message, priority) do
    timestamp = System.system_time(:microsecond)
    id = System.unique_integer([:positive, :monotonic])
    key = {priority, timestamp, id}

    :ets.insert(ets_table, {key, message})
  end

  defp via_tuple(name) when is_atom(name), do: name
  defp via_tuple({_, _, _} = name), do: name
  defp via_tuple(name), do: {:via, Registry, {Epoxi.Queue.Registry, name}}

  defp table_name(name, suffix) when is_atom(name) do
    String.to_atom("#{name}_#{suffix}")
  end

  defp table_name(name, suffix) do
    String.to_atom("queue_#{:erlang.phash2(name)}_#{suffix}")
  end

  defp create_table_dir(table_dir) do
    case File.mkdir_p(table_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, {:create_dir_failed, reason}}
    end
  end

  defp open_dets_table(path, table_name) do
    case :dets.open_file(table_name,
           file: String.to_charlist(path),
           type: :set,
           repair: true,
           auto_save: 60_000
         ) do
      {:ok, ref} -> {:ok, ref}
      {:error, reason} -> {:error, {:dets_open_failed, reason}}
    end
  end

  defp create_ets_table(table_name) do
    ref = :ets.new(table_name, [:ordered_set, :protected, :named_table])
    {:ok, ref}
  rescue
    error -> {:error, {:ets_create_failed, error}}
  end

  defp load_dets_to_ets(dets_ref, ets_ref) do
    case :dets.to_ets(dets_ref, ets_ref) do
      ref when ref == ets_ref -> :ok
      {:error, reason} -> {:error, {:dets_to_ets_failed, reason}}
    end
  end

  defp schedule_sync(interval) do
    Process.send_after(self(), :sync, interval)
  end

  defp do_sync(state) do
    :dets.delete_all_objects(state.dets_table)
    :ets.to_dets(state.ets_table, state.dets_table)
    :dets.sync(state.dets_table)

    :telemetry.execute(
      [:epoxi, :queue, :sync],
      %{count: :ets.info(state.ets_table, :size)},
      %{queue: state.name}
    )

    state
  end
end
