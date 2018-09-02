defmodule Epoxi.SMTP.LocalContext do
  @moduledoc "Responsible to configuring SMTP context to send to mailtrap.io"

  @default_config %{
    port: 2525,
    auth: :never,
    tls: :never
  }

  @doc "Returns %Mailman.Context{} configured for mailtrap"
  @spec set(hostname :: String.t()) :: %Mailman.Context{}
  def set(_hostname) do
    config = struct(Mailman.SmtpConfig, Map.merge(@default_config, %{relay: "0.0.0.0"}))
    %Mailman.Context{
      config: config,
      composer: %Mailman.EexComposeConfig{}
    }
  end
end
