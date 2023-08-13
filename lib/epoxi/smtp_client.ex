defmodule Epoxi.SmtpClient do
  @moduledoc """
  Delivers mail to SMTP servers
  """

  alias Epoxi.{Email, Context, Render, SmtpConfig, Utils}

  @doc """
  Sends an email and blocks until a response is received. Returns an error tuple
  or a binary that is the send receipt returned from the receiving server
  """
  @spec send_blocking(Email.t(), Context.t()) :: {:ok, binary()} | {:error, term()}
  def send_blocking(%Email{} = email, %Context{} = context) do
    message = Render.encode(email, context.compiler)
    config = SmtpConfig.for_email(email, context.config)

    :gen_smtp_client.send_blocking(
      {email.from, email.to, message},
      config
    )
  end

  @doc """
  Send a non-blocking email via a spawned_linked process
  """
  @spec send_async(Email.t(), Context.t(), callback :: function) :: :ok
  def send_async(%Email{} = email, %Context{} = context, callback) do
    message = Render.encode(email)
    config = SmtpConfig.for_email(email, context.config)

    :gen_smtp_client.send(
      {email.from, email.to, message},
      config,
      callback
    )

    :ok
  end

  @doc """
  Delivers email over an existing socket connection, this can be used when
  PIPELINING on the receiving server is available.
  """
  @spec send_bulk([Email.t()], :gen_smtp_client.socket()) ::
          {:ok, :all_queued} | {:error, term(), term()}
  def send_bulk(emails, context) do
    for {domain, emails} <- Utils.group_by_domain(emails) do
      config = SmtpConfig.for_domain(domain, context.config)

      case :gen_smtp_client.open(config) do
        {:ok, socket} ->
          deliver(emails, socket)

        {:error, type, reason} ->
          {:error, type, reason}
      end
    end

    {:ok, :all_queued}
  end

  defp deliver([], _socket) do
    {:ok, :all_queued}
  end

  defp deliver([email | rest], socket) do
    message = Render.encode(email)

    response =
      :gen_smtp_client.deliver(
        socket,
        {email.from, email.to, message}
      )

    case response do
      {:ok, _receipt} ->
        deliver(rest, socket)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
