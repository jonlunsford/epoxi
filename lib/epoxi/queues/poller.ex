defmodule Epoxi.Queues.Poller do
  require Logger
  @moduledoc """
  Acts as a poller for queues, when events are found they are dispatched
  immediately to any subscribed consumers.

  Tentative state structure:
  ```
    %{
      queue_ref: pid of app queue OR name of SQS queue (tbd),
      events: :queue.new, // Internal queue
      pending_demand: 0,
      adapter_module: module() // something that responds to fetch_events
    }
  ```
  """

  use GenStage

  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  ## Public API

  def poll() do
    #Process.send(self(), :poll, [])
  end

  ## Callbacks

  def init(args) do
    {
      :producer,
      %{queue_ref: Epoxi.Queues.Supervisor.available_inbox(),
        events: :queue.new,
        pending_demand: 0,
        adapter_module: args[:adapter_module]}
    }
  end

  def handle_info(:poll, %{queue_ref: queue_ref} = state) do
    found_events = state.adapter_module.fetch_events(queue_ref)
    events =
      found_events
      |> Enum.reduce(state.events, fn event, acc ->
         queue = :queue.in(event, acc)
         queue
      end)

    dispatch_events(%{state | events: events}, [])
  end

  def handle_demand(demand, state) when demand > 0 do
    state = %{state | pending_demand: state.pending_demand + demand}

    :telemetry.execute([:epoxi, :queues, :poller], %{pending_demand: state.pending_demand}, %{})

    dispatch_events(state, [])
  end

  defp dispatch_events(%{pending_demand: 0} = state, to_dispatch) do
    do_dispatch_events(state, to_dispatch)
  end

  defp dispatch_events(state, to_dispatch) do
    case :queue.out(state.events) do
      {{:value, event}, events} ->
        state = %{state | events: events, pending_demand: state.pending_demand - 1}
        dispatch_events(state, [event | to_dispatch])
      {:empty, events} ->
        state = %{state | events: events}
        do_dispatch_events(state, to_dispatch)
    end
  end

  defp do_dispatch_events(state, to_dispatch) do
    if state.pending_demand > 0, do: do_poll()
    to_dispatch = Enum.reverse(to_dispatch)
    {:noreply, to_dispatch, state}
  end

  defp do_poll() do
    Process.send_after(self(), :poll, 100)
  end

  #defp log(message, color \\ :magenta) do
    #Logger.debug("#{__MODULE__}: #{message}", ansi_color: color)
  #end
end
