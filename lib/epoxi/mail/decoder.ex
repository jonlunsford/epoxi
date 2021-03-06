defmodule Epoxi.Mail.Decoder do
  require Logger
  @moduledoc """
  Takes in a list of JSON strings and decodes them as [%MailMan.Email{}] and
  broadcasts the results to it's consumers
  """

  use GenStage

  alias Epoxi.Queues.Inbox
  alias Epoxi.SMTP.Utils

  def start_link(_args) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Callbacks

  def init(:ok) do
    {:producer_consumer,
      :no_state_for_now,
      subscribe_to: [{Inbox, max_demand: 2000, min_demand: 1000}]}
  end

  def handle_events(json_payload, _from, state) do
    #Logger.debug("Decoding #{Enum.count(json_payload)} JSON payloads", ansi_color: :blue)
    :telemetry.execute([:epoxi, :mail, :decoder], %{json_payloads: Enum.count(json_payload)}, %{})

    email_structs =
      json_payload
      |> Task.async_stream(&decode_json/1, max_concurrency: 500)
      |> Task.async_stream(&cast_map_to_email_struct/1, max_concurrency: 1000)
      |> Enum.map(fn {:ok, val} -> val end)
      |> List.flatten()

    #Logger.debug("Produced #{Enum.count(email_structs)} email structs", ansi_color: :blue)
    :telemetry.execute([:epoxi, :mail, :decoder], %{email_structs: Enum.count(email_structs)}, %{})

    {:noreply, email_structs, state}
  end

  defp decode_json(json_string) when is_binary(json_string) do
    case Poison.decode(json_string) do
      {:ok, result} -> result
      {:error, reason} ->
        IO.puts "ERROR PARSING-----------"
        IO.inspect reason
    end
  end

  defp cast_map_to_email_struct({:ok, payload}) when is_map(payload) do
    payload["to"]
    |> Enum.map(&format_map_for_email(&1, payload))
    |> Enum.map(&cast_to_struct/1)
  end

  defp format_map_for_email(email_address, map) when is_map(map) do
    map
    |> Map.put("data", map["data"][email_address])
    |> Map.put("to", [email_address])
  end

  defp cast_to_struct(json_map) when is_map(json_map) do
    map = Utils.atomize_keys(json_map)
    map = update_in(map[:data], fn(m) -> Map.to_list(m) end)
    struct(Mailman.Email, map)
  end
end
