defmodule Epoxi.Mail.Decoder do
  require Logger
  @moduledoc """
  Takes in a list of JSON strings and decodes them as [%MailMan.Email{}] and
  broadcasts the results to it's consumers
  """

  use GenStage

  alias Epoxi.Queues.Poller
  alias Epoxi.SMTP.Utils

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Callbacks

  def init(:ok) do
    {:producer_consumer, :no_state_for_now, subscribe_to: [{Poller, max_demand: 10, min_demand: 8}]}
  end

  def handle_events(events, _from, state) do
    Logger.debug("Decoding #{Enum.count(events)} events", ansi_color: :blue)
    decoded_events =
      events
      |> Enum.map(&decode/1)

    {:noreply, decoded_events, state}
  end

  defp decode(%{email: email}), do: email

  defp decode(event) when is_binary(event) do
    case Poison.decode(event) do
      {:ok, result} ->
        map = Utils.atomize_keys(result)
        map = update_in(map[:data], fn(m) -> Map.to_list(m) end)
        Map.merge(%Mailman.Email{}, map)
      {:error, reason} ->
        # TODO: Handle parsing errors
        IO.puts "ERROR PARSING-----------"
        IO.inspect reason
    end
  end
end
