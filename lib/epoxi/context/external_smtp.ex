defmodule Epoxi.Context.ExternalSmtp do
  defstruct adapter: Epoxi.Adapters.SMTP,
            compiler: Epoxi.EExCompiler,
            config: %Epoxi.SmtpConfig{},
            socket: nil

  @type t :: %__MODULE__{
          adapter: Epoxi.Adapters.SMTP,
          compiler: Epoxi.EExCompiler,
          config: Epoxi.SmtpConfig.t(),
          socket: term()
        }

  def put_config(config, email) do
    from_hostname = Epoxi.Parsing.get_hostname(email.from)

    # TODO: pre-cache/lookup mx records for popular domains
    {_priority, relay} =
      Epoxi.Parsing.get_hostname(email.to)
      |> Epoxi.Utils.mx_lookup()
      |> List.first()

    %{config | relay: relay, hostname: from_hostname}
  end
end

defimpl Epoxi.Adapter, for: Epoxi.Context.ExternalSmtp do
  def send_blocking(context, email, message) do
    config = Epoxi.Context.ExternalSmtp.put_config(context.config, email)

    Epoxi.Adapters.SMTP.send_blocking(config, email, message)
  end

  def send(context, email, message) do
    config = Epoxi.Context.ExternalSmtp.put_config(context.config, email)

    Epoxi.Adapters.SMTP.send(config, email, message)
  end

  def deliver(emails, context) do
    # TODO: Cleaner config for a batch of emails, going to the same relay/host
    config = Epoxi.Context.ExternalSmtp.put_config(context.config, List.first(emails))
    config = Map.to_list(config)

    case :gen_smtp_client.open(config) do
      {:ok, socket} ->
        Epoxi.Adapters.SMTP.deliver(socket, emails)

      {:error, reason} ->
        IO.inspect(reason)
    end
  end
end
