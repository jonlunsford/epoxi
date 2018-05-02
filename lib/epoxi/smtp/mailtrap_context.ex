defmodule Epoxi.SMTP.MailtrapContext do
  @moduledoc "Responsible to configuring SMTP context to send to mailtrap.io"

  @default_config %{
    port: 2525,
    username: "574230c2555513",
    password: "4a77a9532abeb5",
    auth: :always,
    tls: :always
  }

  @doc "Returns %Mailman.Context{} configured for mailtrap"
  @spec set(hostname :: String.t()) :: %Mailman.Context{}
  def set(_hostname) do
    config = struct(Mailman.SmtpConfig, Map.merge(@default_config, %{relay: "smtp.mailtrap.io"}))
    %Mailman.Context{
      config: config,
      composer: %Mailman.EexComposeConfig{}
    }
  end
end
