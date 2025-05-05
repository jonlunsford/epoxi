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
    * `:queue` - (required) The name of the Epoxi.Queue to pull messages from
    * `:poll_interval` - (optional) Milliseconds between queue polling attempts, defaults to 5000
    * `:max_retries` - (optional) Maximum number of retry attempts for failed messages, defaults to 5
    * `:broadway` - Broadway configuration options
  """
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    queue = Keyword.get(opts, :queue)

    if queue == nil do
      raise ArgumentError,
            "invalid configuration given to Epoxi.Queue.Producer.init/1, required :queue option not found"
    end

    poll_interval = Keyword.get(opts, :poll_interval, 5_000)
    max_retries = Keyword.get(opts, :max_retries, 5)
    ack_ref = opts[:broadway][:name]

    :persistent_term.put(ack_ref, %{queue: queue})

    state = %{
      demand: 0,
      queue: queue,
      ack_ref: ack_ref,
      poll_interval: poll_interval,
      max_retries: max_retries
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
    %{queue: queue} = :persistent_term.get(ack_ref)

    unless Enum.empty?(successful) do
      :telemetry.execute(
        [:epoxi, :queue, :messages_processed],
        %{count: length(successful)},
        %{queue: queue}
      )
    end

    {retrying, _dead} =
      Enum.split_with(failed, &match?(%{status: {:failed, :retrying}}, &1))

    Epoxi.Queue.enqueue_many(queue, Enum.map(retrying, & &1.data))
    # Epoxi.Queue.enqueue_many(:dead, Enum.map(dead, & &1.data))

    :ok
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp fetch_events(%{demand: 0} = state), do: {[], state}

  defp fetch_events(%{demand: demand, queue: queue, ack_ref: ack_ref} = state) do
    metadata = %{queue: queue, demand: demand}

    events =
      :telemetry.span([:epoxi, :queue, :fetch_messages], metadata, fn ->
        messages = fetch_multiple(queue, demand, [])
        events = Enum.map(messages, &transform_message(&1, ack_ref))

        {events, Map.put(metadata, :messages, messages)}
      end)

    {events, %{state | demand: demand - length(events)}}
  end

  defp fetch_multiple(_queue, 0, acc), do: Enum.reverse(acc)

  defp fetch_multiple(queue, n, acc) when n > 0 do
    case Epoxi.Queue.dequeue(queue) do
      {:ok, msg} -> fetch_multiple(queue, n - 1, [msg | acc])
      :empty -> Enum.reverse(acc)
    end
  end

  defp transform_message(message, ack_ref) do
    %Broadway.Message{
      data: message,
      acknowledger: {__MODULE__, ack_ref, []}
    }
  end
end
