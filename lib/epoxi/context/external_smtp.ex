defmodule Epoxi.Context.ExternalSmtp do
  defstruct adapter: Epoxi.Adapters.SMTP,
            compiler: Epoxi.Compilers.EEx,
            config: %Epoxi.SmtpConfig{}

  @type t :: %__MODULE__{
          adapter: Epoxi.Adapters.SMTP,
          compiler: Epoxi.Compilers.EEx,
          config: Epoxi.SmtpConfig.t()
        }
end

defimpl Epoxi.Adapter, for: Epoxi.Context.ExternalSmtp do
  def send_blocking(context, email, message) do
    from_hostname = Epoxi.Parsing.get_hostname(email.from)

    # TODO: pre-cache/lookup mx records for popular domains
    {_priority, relay} =
      Epoxi.Parsing.get_hostname(email.to)
      |> Epoxi.Utils.mx_lookup()
      |> List.first()

    config = %{context.config | relay: relay, hostname: from_hostname}

    Epoxi.Adapters.SMTP.send_blocking(config, email, message)
  end
end
