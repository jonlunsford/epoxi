defmodule Epoxi.Mail.Dispatcher do
  @moduledoc "GenStage to emit emails for consumers"

  use GenStage

  alias Epoxi.Mail.Encoder

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Callbacks

  def init(:ok) do
    {
      :producer_consumer,
      :no_state_for_now,
      subscribe_to: [{Encoder, max_demand: 5}], dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_events(events, _from, state) do
    {:noreply, events, state}
  end
end
