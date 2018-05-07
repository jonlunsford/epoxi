defmodule Epoxi.Mail.Encoder do
  @moduledoc """
  Takes in a list of JSON strings and encodes them as [%MailMan.Email{}] and
  broadcasts the results to it's consumers

  TODO:
  - Change to a producer_consumer
  - Implement JSON -> Map -> %MailMan.Email{} transformation using Poison.encode!
  """

  use GenStage

  alias Epoxi.Queues.Poller

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Callbacks

  def init(:ok) do
    {:producer_consumer, :no_state_for_now, subscribe_to: [Poller]}
  end

  def handle_events(events, _from, state) do
    {:noreply, events, state}
  end
end
