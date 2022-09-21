defmodule Epoxi.Context.LocalSmtp do
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
  def send_blocking(context, email, message) do
    Epoxi.Adapters.SMTP.send_blocking(context.config, email, message)
  end

  def send(context, email, message) do
    Epoxi.Adapters.SMTP.send(context.config, email, message)
  end

  def deliver(context, emails) do
    Epoxi.Adapters.SMTP.deliver(emails, context)
  end
end
