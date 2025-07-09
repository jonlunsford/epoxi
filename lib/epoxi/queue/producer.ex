defmodule Epoxi.Queue.Producer do
  @moduledoc """
  A Broadway producer that pulls items from Epoxi.Queue instances.

  This module implements both the `Broadway.Producer` and `Broadway.Acknowledger` behaviors,
  allowing it to integrate with Broadway pipelines for processing queue messages.
  It handles:
    * Pulling messages from a specified Epoxi.Queue at configurable intervals
    * Managing demand from Broadway consumers
    * Acknowledging successful message processing
    * Retrying failed messages
  """

  use GenStage
  @behaviour Broadway.Producer
  @behaviour Broadway.Acknowledger

  require Logger

  @doc """
  Starts a new producer linked to the current process.

  ## Options
    * `:inbox_name` - (required) The name of the Epoxi.Queue to pull messages from
    * `:dead_letter_name` - (required) the name of the Epoxi.Queue to push dead messages to
    * `:poll_interval` - (optional) Milliseconds between queue polling attempts, defaults to 5000
    * `:max_retries` - (optional) Maximum number of retry attempts for failed messages, defaults to 5
    * `:broadway` - Broadway configuration options
  """
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    ack_ref = opts[:broadway][:name]
    inbox_ref = suffix_atom(ack_ref, "inbox")
    dead_letter_ref = suffix_atom(ack_ref, "dlq")

    poll_interval = Keyword.get(opts, :poll_interval, 5_000)
    max_retries = Keyword.get(opts, :max_retries, 5)

    :persistent_term.put(ack_ref, %{
      inbox_ref: inbox_ref,
      dead_letter_ref: dead_letter_ref
    })

    state = %{
      demand: 0,
      inbox_ref: inbox_ref,
      dead_letter_ref: dead_letter_ref,
      ack_ref: ack_ref,
      poll_interval: poll_interval,
      max_retries: max_retries,
      transformer: {__MODULE__, :transform, [ack_ref]}
    }

    schedule_poll(poll_interval)

    {:producer, state}
  end

  @impl true
  def handle_demand(incoming_demand, %{demand: pending_demand} = state) do
    new_demand = pending_demand + incoming_demand
    new_state = %{state | demand: new_demand}

    {events, newer_state} = fetch_events(new_state)

    {:noreply, events, newer_state}
  end

  @impl true
  def handle_info(:poll, %{demand: demand} = state) when demand > 0 do
    schedule_poll(state.poll_interval)

    {events, new_state} = fetch_events(state)

    {:noreply, events, new_state}
  end

  @impl true
  def handle_info(:poll, %{demand: demand} = state) when demand <= 0 do
    schedule_poll(state.poll_interval)

    {:noreply, [], state}
  end

  @doc """
  Acknowledges messages processed by Broadway.

  This function follows the Broadway.Acknowledger behavior and handles:
    * Successful messages - Emits telemetry events for processed messages
    * Failed messages - Retries messages marked for retry by re-enqueueing them

  ## Parameters
    * `ack_ref` - Reference to the acknowledgement context
    * `successful` - List of messages successfully processed
    * `failed` - List of messages that failed processing
  """
  @impl Broadway.Acknowledger
  def ack(ack_ref, successful, failed) do
    %{
      inbox_ref: inbox_ref,
      dead_letter_ref: dead_letter_ref
    } = :persistent_term.get(ack_ref)

    {retrying, dead} =
      Enum.split_with(failed, &match?(%{status: {:failed, :retrying}}, &1))

    Epoxi.Queue.enqueue_many(inbox_ref, Enum.map(retrying, & &1.data))
    Epoxi.Queue.enqueue_many(dead_letter_ref, Enum.map(dead, & &1.data))

    :telemetry.execute(
      [:epoxi, :queue, :batch_processed],
      %{successful: length(successful), failed: length(failed)},
      %{inbox_ref: inbox_ref, dead_letter_ref: dead_letter_ref}
    )

    :ok
  end

  @impl Broadway.Producer
  def prepare_for_start(_module, opts) do
    name = Keyword.get(opts, :name)
    inbox_ref = suffix_atom(name, "inbox")
    dead_letter_ref = suffix_atom(name, "dlq")

    children = [
      {Epoxi.Queue, [name: inbox_ref]},
      {Epoxi.Queue, [name: dead_letter_ref]}
    ]

    {children, opts}
  end

  @impl Broadway.Producer
  def prepare_for_draining(state) do
    with :ok <- Epoxi.Queue.sync(state.inbox_ref),
         :ok <- Epoxi.Queue.sync(state.dead_letter_ref) do
      # Check if both queues are empty and can be cleaned up
      maybe_cleanup_queues(state)
      {:noreply, [], state}
    else
      error -> {:stop, {:failed_to_sync_to_disk, error}, state}
    end
  end

  def transform(message, ack_ref) do
    %Broadway.Message{
      data: message,
      acknowledger: {__MODULE__, ack_ref, []}
    }
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp fetch_events(%{demand: 0} = state), do: {[], state}

  defp fetch_events(%{demand: demand, inbox_ref: inbox_ref, ack_ref: ack_ref} = state) do
    metadata = %{inbox_ref: inbox_ref, demand: demand}

    events =
      :telemetry.span([:epoxi, :queue, :fetch_messages], metadata, fn ->
        messages = fetch_multiple(inbox_ref, demand, [])
        events = Enum.map(messages, &transform(&1, ack_ref))

        {events, Map.put(metadata, :messages, messages)}
      end)

    {events, %{state | demand: demand - length(events)}}
  end

  defp fetch_multiple(_inbox_ref, 0, acc), do: Enum.reverse(acc)

  defp fetch_multiple(inbox_ref, n, acc) when n > 0 do
    case Epoxi.Queue.dequeue(inbox_ref) do
      {:ok, msg} -> fetch_multiple(inbox_ref, n - 1, [msg | acc])
      :empty -> Enum.reverse(acc)
    end
  end

  defp suffix_atom(atom, suffix) do
    string = Atom.to_string(atom)

    prefixed_string = "#{string}_#{suffix}"

    String.to_atom(prefixed_string)
  end

  defp maybe_cleanup_queues(state) do
    # Check if both queues are empty
    inbox_empty = Epoxi.Queue.empty?(state.inbox_ref)
    dlq_empty = Epoxi.Queue.empty?(state.dead_letter_ref)

    if inbox_empty and dlq_empty do
      cleanup_queues(state)
    else
      Logger.debug(
        "Skipping queue cleanup - inbox empty: #{inbox_empty}, DLQ empty: #{dlq_empty}"
      )
    end
  end

  defp cleanup_queues(state) do
    Logger.info("Cleaning up empty queues for pipeline: #{state.ack_ref}")

    # Start cleanup in a separate task to avoid blocking the draining process
    Task.start(fn ->
      cleanup_queue_safely(state.inbox_ref, "inbox")
      cleanup_queue_safely(state.dead_letter_ref, "dlq")

      :telemetry.execute(
        [:epoxi, :queue, :pipeline_cleanup],
        %{queues_cleaned: 2},
        %{pipeline: state.ack_ref, inbox: state.inbox_ref, dlq: state.dead_letter_ref}
      )
    end)
  end

  defp cleanup_queue_safely(queue_ref, queue_type) do
    case Epoxi.Queue.destroy(queue_ref) do
      :ok ->
        Logger.info("Successfully cleaned up #{queue_type} queue: #{queue_ref}")

      {:error, {:queue_not_empty, count}} ->
        Logger.warning(
          "Cannot cleanup #{queue_type} queue #{queue_ref} - not empty (#{count} messages)"
        )

      {:error, reason} ->
        Logger.error("Failed to cleanup #{queue_type} queue #{queue_ref}: #{inspect(reason)}")
    end
  end
end
