defmodule Epoxi.MailEncoder do
  @moduledoc """
  Takes in a list of JSON strings and encodes them as [%MailMan.Email{}] and
  broadcasts the results to it's consumers
  """

  use GenStage

  alias Epoxi.Queues.Poller

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Callbacks

  def init(:ok) do
    {:consumer, :no_state_for_now, subscribe_to: [Poller]}
  end

  def handle_events(events, _from, state) do
    IO.puts "TODO: Transform this into %MailMan.Email{} structs"
    IO.inspect events
    {:noreply, [], state}
  end
end
