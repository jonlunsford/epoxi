defmodule Epoxi.JSONDecoder do
  @moduledoc """
  Takes in a list of JSON strings and decodes them as `%Epoxi.Email{}`
  """

  require Logger

  def decode(json_string) when is_binary(json_string) do
    case Jason.decode(json_string, [keys: :atoms]) do
      {:ok, result} -> cast_map_to_email_struct(result)
      {:error, _reason} -> {:error, "Failed to decode JSON."}
    end
  end

  defp cast_map_to_email_struct(payload) when is_map(payload) do
    payload[:to]
    |> Enum.map(&format_map_for_email(&1, payload))
    |> Enum.map(&cast_to_struct/1)
  end

  defp format_map_for_email(email_address, map) when is_map(map) do
    map
    |> Map.put("data", map["data"][email_address])
    |> Map.put("to", [email_address])
  end

  defp cast_to_struct(json_map) when is_map(json_map) do
    map = update_in(json_map[:data], fn(m) -> Map.to_list(m) end)
    struct(Epoxi.Email, map)
  end
end
