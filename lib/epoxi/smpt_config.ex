defmodule Epoxi.SmtpConfig do
  @moduledoc "Config for external SMPT adapters"

  # Defaults are bare minimum to get a delivery. Ideally, serious senders
  # configure ssl, tls, dkim, etc.
  defstruct relay: "",
            hostname: "",
            port: 25,
            ssl: false,
            auth: :never,
            tls: false

  @type t :: %__MODULE__{
          relay: String.t(),
          hostname: String.t(),
          port: integer,
          ssl: boolean,
          auth: Atom.t(),
          tls: boolean
        }
end

defimpl Epoxi.Adapter, for: Epoxi.SmtpConfig do
  def send_blocking(config, email, message) do
    Epoxi.ExternalSmtpAdapter.send_blocking(config, email, message)
  end
end
