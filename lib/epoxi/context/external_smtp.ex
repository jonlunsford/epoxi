defmodule Epoxi.Context.ExternalSmtp do
  @moduledoc """
  Context for sending emails to an external SMTP server.
  """
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

  def put_config(%Epoxi.SmtpConfig{relay: ""} = config, email) do
    from_hostname = Epoxi.Parsing.get_hostname(email.from)

    # TODO: pre-cache/lookup mx records for popular domains
    {_priority, relay} =
      Epoxi.Parsing.get_hostname(email.to)
      |> Epoxi.Utils.mx_lookup()
      |> List.first()

    %{config | relay: relay, hostname: from_hostname}
  end

  def put_config(config, _email), do: config

  def partition(emails) do
    partition(emails, partition_size: 100)
  end

  @doc """
  Accepts a list of emails and partitions them by the recipients (to) hostname.
  """
  @spec partition([Epoxi.Email.t()], partition_size: integer) ::
          [{String.t(), [Epoxi.Email.t()]}]
  def partition(emails, partition_size: partition_size) do
    emails
    |> Enum.group_by(fn email ->
      Epoxi.Parsing.get_hostname(email.to)
    end)
    |> Enum.flat_map(fn {hostname, emails} ->
      emails
      |> Enum.chunk_every(partition_size)
      |> Enum.map(fn part -> {hostname, part} end)
    end)
  end
end

defimpl Epoxi.Adapter, for: Epoxi.Context.ExternalSmtp do
  alias Epoxi.Context.ExternalSmtp

  def send_blocking(context, email, message) do
    config = ExternalSmtp.put_config(context.config, email)

    Epoxi.Adapters.SMTP.send_blocking(config, email, message)
  end

  def send(context, email, message) do
    config = ExternalSmtp.put_config(context.config, email)

    Epoxi.Adapters.SMTP.send(config, email, message)
  end

  def deliver(context, emails) do
    # TODO: Cleaner config for a batch of emails, going to the same relay/host

    # partitions = ExternalSmtp.partition(emails, partition_size: context.config.max_batch_size)
    config = ExternalSmtp.put_config(context.config, List.first(emails))

    case :gen_smtp_client.open(config) do
      {:ok, socket} ->
        Epoxi.Adapters.SMTP.deliver(socket, emails)

      {:error, type, reason} ->
        {:error, type, reason}
    end
  end
end
