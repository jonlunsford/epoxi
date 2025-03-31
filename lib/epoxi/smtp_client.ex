defmodule Epoxi.SmtpClient do
  @moduledoc """
  Delivers mail to SMTP servers
  """
  require Logger

  alias Epoxi.{Email, Context, Render, SmtpConfig}

  @doc """
  Sends an email and blocks until a response is received. Returns an error tuple
  or a binary that is the send receipt returned from the receiving server
  """
  @spec send_blocking(Email.t(), Context.t()) :: {:ok, binary()} | {:error, term()}
  def send_blocking(%Email{} = email, %Context{} = context) do
    email = Email.put_content_type(email)
    message = Render.encode(email, context.compiler)
    config = SmtpConfig.for_email(context.config, email)

    case :gen_smtp_client.send_blocking(
           {email.from, email.to, message},
           config
         ) do
      {:ok, receipt} -> {:ok, receipt}
      receipt when is_binary(receipt) -> {:ok, receipt}
      error -> {:error, error}
    end
  end

  @doc """
  Send a non-blocking email via a spawned_linked process
  """
  @spec send_async(Email.t(), Context.t(), callback :: function) :: :ok
  def send_async(%Email{} = email, %Context{} = context, callback) do
    email = Email.put_content_type(email)
    message = Render.encode(email)
    config = SmtpConfig.for_email(context.config, email)

    :gen_smtp_client.send(
      {email.from, email.to, message},
      config,
      callback
    )

    :ok
  end

  @doc """
  Delivers email over a persistent socket connection, this can be used when
  PIPELINING on the receiving server is available.
  """
  @spec send_bulk([Email.t()], :gen_smtp_client.socket(), domain :: String.t()) ::
          {:ok, [Email.at()]} | {:error, term(), [Email.t()]}
  def send_bulk(emails, context, domain \\ "") do
    config = SmtpConfig.for_domain(context.config, domain)

    batch_result = %{
      success: [],
      failure: []
    }

    case(:gen_smtp_client.open(config)) do
      {:ok, socket} ->
        deliver(emails, socket, batch_result)

      {:error, type, reason} ->
        {:error, type, reason}
    end
  end

  defp deliver([], socket, batch_result) do
    :gen_smtp_client.close(socket)
    {:ok, batch_result}
  end

  defp deliver([email | rest], socket, batch_result) do
    message = Render.encode(email)

    response =
      :gen_smtp_client.deliver(
        socket,
        {email.from, email.to, message}
      )

    case response do
      {:ok, receipt} ->
        email = Email.put_log_entry(email, receipt)

        deliver(
          rest,
          socket,
          %{batch_result | success: [email | batch_result.success]}
        )

      {:error, reason} ->
        email = Email.put_log_entry(email, reason)

        deliver(
          rest,
          socket,
          %{batch_result | failure: [email | batch_result.failure]}
        )
    end
  end
end
