defmodule Epoxi.Mail.JSONDecoder do
  @moduledoc """
  Takes in a list of JSON strings and decodes them as [%MailMan.Email{}] and
  broadcasts the results to it's consumers
  """

  require Logger

  alias Epoxi.SMTP.Utils

  def decode(json_string) when is_binary(json_string) do
    case Poison.decode(json_string) do
      {:ok, result} -> cast_map_to_email_struct(result)
      {:error, _reason} -> {:error, "Failed to decode JSON."}
    end
  end

  defp cast_map_to_email_struct(payload) when is_map(payload) do
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
