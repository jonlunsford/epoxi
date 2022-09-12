defmodule Epoxi.Render do
  @moduledoc """
  Renders %Epoxi.Email{} structs into strings by transforming to a valid gen_smtp
  struct and compiling text/html bodies via a composer (EEx for example).
  """

  alias Epoxi.Email
  alias Epoxi.Parsing

  def encode(%Email{} = email) do
    render(email)
    |> :mimemail.encode()
  end

  def render(%Email{} = email) do
    email = Email.put_content_type(email)
    [type, subtype] = String.split(email.content_type, "/")

    {
      type,
      subtype,
      headers_for(email),
      parameters_for(email),
      bodies_for(email)
    }
  end

  def headers_for(%Email{} = email) do
    additional_headers =
      email.headers
      |> Enum.map(fn {header, value} ->
        {Atom.to_string(header), value}
      end)
      |> Enum.reverse()

    headers = [
      {"From", email.from |> addresses_to_header_value()},
      {"To", email.to |> addresses_to_header_value()},
      {"Subject", email.subject},
      {"reply-to", email.reply_to},
      {"Cc", email.cc |> addresses_to_header_value()},
      {"Bcc", email.bcc |> addresses_to_header_value()}
    ] ++ additional_headers

    headers
    |> Enum.reject(fn {_header, value} ->
      is_nil(value) || value === "" || value === []
    end)
  end

  def headers_for(_), do: []

  def parameters_for(_part) do
    %{
      "transfer-encoding": "quoted-printable",
      "content-type-params": [],
      disposition: "inline",
      "disposition-params": []
    }
  end

  def bodies_for(%Email{content_type: "multipart/mixed"} = email) do
    [
      body_for(email, :plain),
      body_for(email, :html)
    ]
  end

  def bodies_for(%Email{content_type: "text/plain"} = email) do
    [
      body_for(email, :plain)
    ]
  end

  def bodies_for(%Email{content_type: "text/html"} = email) do
    [
      body_for(email, :html)
    ]
  end

  def bodies_for(%Email{content_type: "multipart/alternative"} = email) do
    [
      body_for(email, :plain),
      body_for(email, :html)
    ]
  end

  def body_for(%Email{} = email, :plain) do
    {
      "text",
      "plain",
      [{"Content-type", "text/plain"}],
      parameters_for(email),
      email.text
    }
  end

  def body_for(%Email{} = email, :html) do
    {
      "text",
      "html",
      [{"Content-type", "text/html"}],
      parameters_for(email),
      email.html
    }
  end

  def addresses_to_header_value(addresses) do
    addresses
    |> Parsing.normalize_addresses()
    |> Enum.join(", ")
  end
end
