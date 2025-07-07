defmodule Epoxi.SmtpConfig do
  @moduledoc "Config for external SMTP adapters"

  require Logger

  # Defaults are bare minimum to get a delivery. Ideally, serious senders
  # configure ssl, tls, dkim, etc.
  defstruct relay: "localhost",
            hostname: "localhost",
            port: 2525,
            ssl: false,
            auth: :if_available,
            tls: :if_available,
            no_mx_lookups: false,
            on_transaction_error: :reset,
            username: "",
            retries: 3,
            password: ""

  # trace_fun: &Epoxi.SmtpConfig.trace/2

  @type t :: %__MODULE__{
          relay: String.t(),
          hostname: String.t(),
          port: integer,
          ssl: boolean,
          auth: Atom.t(),
          tls: boolean,
          no_mx_lookups: boolean,
          on_transaction_error: Atom.t(),
          username: String.t(),
          password: String.t(),
          retries: number
        }

  alias Epoxi.{Email, Utils, SmtpConfig, Parsing}

  @spec new(opts :: Keyword.t()) :: SmtpConfig.t()
  def new(opts \\ []) do
    struct(SmtpConfig, opts)
  end

  def to_keyword_list(%SmtpConfig{} = smtp_config) do
    smtp_config
    |> Map.from_struct()
    |> Utils.map_to_list()
  end

  @spec for_email(t(), Email.t()) :: Keyword.t()
  def for_email(%SmtpConfig{} = config, %Email{} = email) do
    hostname = Parsing.get_hostname(email.to)
    for_domain(config, hostname)
  end

  @spec for_domain(t(), Strong.t()) :: Keyword.t()
  def for_domain(%SmtpConfig{} = config, domain) do
    relay =
      case Epoxi.DNS.MxLookup.lookup(domain) do
        [first_record | _rest] ->
          {_priority, relay} = first_record
          relay

        [] ->
          config.relay
      end

    config
    |> Map.from_struct()
    |> Map.put(:relay, relay)
    |> Map.put(:hostname, domain)
    |> Utils.map_to_list()
  end

  def trace(formatted_string, args) do
    interpolated = :io_lib.format(formatted_string, args) |> to_string()
    Logger.info("SMTP trace: #{interpolated}")
  end
end
