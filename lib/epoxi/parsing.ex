defmodule Epoxi.Parsing do
  @moduledoc "Responsible for parsing various components of an email"

  @doc """
  Gets the hostname from an email address

  Examples:

      iex> Epoxi.Parsing.get_hostname("hello@example.com")
      "example.com"

      iex> Epoxi.Parsing.get_hostname("hello@trailing.com  ")
      "trailing.com"

      iex> Epoxi.Parsing.get_hostname("Full Name <hello@test.com>")
      "test.com"

      iex> Epoxi.Parsing.get_hostname("Full Name <  hello@leading.com  >  ")
      "leading.com"

      iex> Epoxi.Parsing.get_hostname(["list@test.com"])
      "test.com"
  """
  def get_hostname(address) when is_bitstring(address) do
    parts = String.split(address, "<")

    case length(parts) do
      1 ->
        parts
        |> hd
        |> String.split("@")
        |> List.last()
        |> String.trim()

      2 ->
        parts
        |> List.last()
        |> String.split(">")
        |> hd
        |> String.split("@")
        |> List.last()
        |> String.trim()
    end
  end

  def get_hostname(addresses) when is_list(addresses) do
    [email | _rest] = addresses

    get_hostname(email)
  end

  @doc """
  Normalizes email address formats as: "Name <address@foo.com>"

  Examples:

      iex> Epoxi.Parsing.normalize_addresses(["foo@test.com"])
      ["Foo <foo@test.com>"]

      iex> Epoxi.Parsing.normalize_addresses(["foo@test.com", "bar@test.com"])
      ["Foo <foo@test.com>", "Bar <bar@test.com>"]

      iex> Epoxi.Parsing.normalize_addresses(["Bar <biz@test.com>"])
      ["Bar <biz@test.com>"]
  """
  def normalize_addresses(addresses) when is_list(addresses) do
    addresses
    |> Enum.map(&address_to_name_format/1)
  end

  def normalize_addresses(addresses) when is_bitstring(addresses) do
    addresses =
      addresses
      |> String.split(",")
      |> Enum.map(fn string -> String.trim(string) end)

    case Enum.count(addresses) > 1 do
      true ->
        normalize_addresses(addresses)

      false ->
        formatted =
          addresses
          |> List.first()
          |> address_to_name_format()

        [formatted]
    end
  end

  def address_to_name_format(address) do
    case address |> String.split("<") |> Enum.count() > 1 do
      true ->
        address

      false ->
        name =
          address
          |> String.split("@")
          |> List.first()
          |> String.split(~r/([^\w\s]|_)/)
          |> Enum.map_join(" ", &String.capitalize/1)

        "#{name} <#{address}>"
    end
  end
end
