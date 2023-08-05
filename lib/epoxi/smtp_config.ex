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
          username: String.t(),
          password: String.t(),
          protocol: Atom.t(),
          retries: number
        }
end
