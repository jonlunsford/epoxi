defmodule Epoxi.Render do
  @moduledoc """
  Renders %Epoxi.Email{} structs into strings by transforming to a valid gen_smtp
  struct and compiling text/html bodies via a composer (EEx for example).
  """

  alias Epoxi.DKIM.{Config, Registry}
  alias Epoxi.Email
  alias Epoxi.Parsing

  def encode(%Email{} = email, compiler \\ Epoxi.EExCompiler) do
    dkim_opts = dkim_for(email)

    email
    |> compiler.compile()
    |> render()
    |> :mimemail.encode(dkim_opts)
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

    headers =
      [
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

  @doc """
  Retrieves DKIM options for an email based on the from domain.

  Looks up DKIM configuration from the registry using the sender's domain.
  If a config is found and active, returns DKIM signing options.
  Otherwise returns an empty list (no DKIM signing).

  ## Parameters

    * `email` - The email struct containing the from address

  ## Returns

    * DKIM options keyword list for mimemail encoding
    * Empty list if no DKIM config found or decryption fails
  """
  @spec dkim_for(Email.t()) :: keyword()
  def dkim_for(%Email{from: from}) do
    domain = Parsing.get_hostname(from)

    case Registry.lookup(domain) do
      {:ok, config} ->
        case Config.decrypt_private_key(config) do
          {:ok, private_key} ->
            [
              s: config.selector,
              d: config.domain,
              private_key: private_key
            ]

          {:error, reason} ->
            require Logger

            Logger.warning(
              "Failed to decrypt DKIM private key for domain #{domain}: #{inspect(reason)}"
            )

            []
        end

      {:error, :not_found} ->
        # No DKIM config for this domain - send without DKIM
        []
    end
  end
end
