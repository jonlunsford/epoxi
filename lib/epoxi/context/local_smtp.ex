defmodule Epoxi.Context.LocalSmtp do
  @moduledoc """
  Context for sending emails to a local SMTP server.
  """
  defstruct adapter: Epoxi.Adapters.SMTP,
            compiler: Epoxi.EExCompiler,
            socket: nil,
            config: %Epoxi.SmtpConfig{
              port: 2525,
              relay: "localhost",
              hostname: "localhost",
              auth: :never
            }

  @type t :: %__MODULE__{
          adapter: Epoxi.Adapters.SMTP,
          compiler: Epoxi.EExCompiler,
          socket: term(),
          config: Epoxi.SmtpConfig.t()
        }
end

defimpl Epoxi.Adapter, for: Epoxi.Context.LocalSmtp do
  def send_blocking(email, context) do
    Epoxi.Adapters.SMTP.send_blocking(email, context.config)
  end

  def send(email, context) do
    Epoxi.Adapters.SMTP.send(email, context.config)
  end

  def deliver(emails, context) do
    config = Map.to_list(context.config)

    case :gen_smtp_client.open(config) do
      {:ok, socket} ->
        Epoxi.Adapters.SMTP.deliver(emails, socket)

      {:error, type, reason} ->
        {:error, type, reason}
    end
  end
end
