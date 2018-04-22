defmodule Epoxi.SMTP.Parsing do
  @moduledoc "Responsible for parsing various components of an email"

  @doc """
  Gets the hostname from an email address

  Examples:

      iex> Epoxi.SMTP.Parsing.get_hostname("hello@example.com")
      "example.com"

      iex> Epoxi.SMTP.Parsing.get_hostname("hello@trailing.com  ")
      "trailing.com"

      iex> Epoxi.SMTP.Parsing.get_hostname("Full Name <hello@test.com>")
      "test.com"

      iex> Epoxi.SMTP.Parsing.get_hostname("Full Name <  hello@leading.com  >  ")
      "leading.com"
  """
  def get_hostname(address) do
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
end
