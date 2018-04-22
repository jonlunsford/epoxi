defmodule Epoxi.SMTP.Context do
  @moduledoc "Responsible to configuring SMTP context"

  @default_config %{
    port: 25,
    auth: :never,
    tls: :always
  }

  @doc "Returns %Mailman.Context{} configured with the passed in hostname"
  @spec set(hostname :: String.t()) :: %Mailman.Context{}
  def set(hostname) do
    config = struct(Mailman.SmtpConfig, Map.merge(@default_config, %{relay: hostname}))
    %Mailman.Context{
      config: config,
      composer: %Mailman.EexComposeConfig{}
    }
  end
end
