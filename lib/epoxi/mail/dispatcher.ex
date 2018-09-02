defmodule Epoxi.Mail.Dispatcher do
  require Logger
  @moduledoc "GenStage to emit emails for consumers"

  use GenStage

  alias Epoxi.Mail.Decoder

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Callbacks

  def init(:ok) do
    {
      :producer_consumer,
      :no_state_for_now,
      subscribe_to: [{Decoder, max_demand: 5, min_demand: 4}], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_events(events, _from, state) do
    Logger.debug("Dispatching #{Enum.count(events)} events", ansi_color: :green)
    {:noreply, events, state}
  end
end
