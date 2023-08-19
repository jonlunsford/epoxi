defmodule Epoxi.SmtpConfig do
  @moduledoc "Config for external SMTP adapters"

  # Defaults are bare minimum to get a delivery. Ideally, serious senders
  # configure ssl, tls, dkim, etc.
  defstruct relay: "",
            hostname: "",
            port: 25,
            ssl: false,
            auth: :never,
            tls: false,
            max_batch_size: 100,
            no_mx_lookups: true,
            on_transaction_error: :reset,
            username: "",
            retries: 1,
            protocol: :smtp,
            password: ""

  @type t :: %__MODULE__{
          relay: String.t(),
          hostname: String.t(),
          port: integer,
          ssl: boolean,
          auth: Atom.t(),
          tls: boolean,
          max_batch_size: integer,
          no_mx_lookups: boolean,
          on_transaction_error: Atom.t(),
          username: String.t(),
          password: String.t(),
          protocol: Atom.t(),
          retries: number
        }

  alias Epoxi.{Email, Utils, SmtpConfig, Parsing}

  @spec for_email(Email.t(), t()) :: Keyword.t()
  def for_email(%Email{} = email, %SmtpConfig{} = config) do
    Parsing.get_hostname(email.to)
    |> for_domain(config)
  end

  @spec for_domain(String.t(), t()) :: Keyword.t()
  def for_domain(domain, %SmtpConfig{} = config) do
    relay =
      case Utils.mx_lookup(domain) do
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
end
