defmodule Epoxi.JSONDecoder do
  @moduledoc """
  Takes in a list of JSON strings and decodes them as `%Epoxi.Email{}`
  """

  require Logger

  def decode(json_string) when is_binary(json_string) do
    with {:ok, decoded} <- JSON.decode(json_string),
         map <- Epoxi.Utils.atomize_keys(decoded),
         emails <- cast_map_to_email_struct(map) do
      emails
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def decode(decoded_json) when is_map(decoded_json) do
    decoded_json
    |> Epoxi.Utils.atomize_keys()
    |> cast_map_to_email_struct()
  end

  defp cast_map_to_email_struct(payload) when is_map(payload) do
    payload[:to]
    |> Enum.map(&format_map_for_email(&1, payload))
    |> Enum.map(&cast_to_struct/1)
  end

  defp format_map_for_email(email_address, map) when is_map(map) do
    %{map | data: get_in(map, [:data, :"#{email_address}"]), to: [email_address]}
  end

  defp cast_to_struct(json_map) when is_map(json_map) do
    map = update_in(json_map[:data], fn m -> Map.to_list(m) end)
    struct(Epoxi.Email, map)
  end
end
