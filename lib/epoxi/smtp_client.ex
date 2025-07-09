defmodule Epoxi.SmtpClient do
  @moduledoc """
  Delivers mail to SMTP servers
  """
  require Logger

  alias Epoxi.{Email, Render, SmtpConfig}

  @doc """
  Sends an email and blocks until a response is received. Returns an error tuple
  or a binary that is the send receipt returned from the receiving server
  """
  @spec send_blocking(Email.t(), opts :: Keyword.t()) :: {:ok, binary()} | {:error, term()}
  def send_blocking(%Email{} = email, opts \\ []) do
    email = Email.put_content_type(email)
    message = Render.encode(email)

    config =
      opts
      |> SmtpConfig.new()
      |> SmtpConfig.to_keyword_list()

    case :gen_smtp_client.send_blocking(
           {email.from, email.to, message},
           config
         ) do
      receipt when is_binary(receipt) -> {:ok, receipt}
      error -> {:error, error}
    end
  end

  @doc """
  Send a non-blocking email via a spawned_linked process
  """
  @spec send_async(Email.t(), opts :: Keyword.t(), callback :: function | nil | :undefined) :: :ok
  def send_async(%Email{} = email, opts \\ [], callback \\ :undefined) do
    email = Email.put_content_type(email)
    message = Render.encode(email)

    config =
      opts
      |> SmtpConfig.new()
      |> SmtpConfig.to_keyword_list()

    callback = if callback == nil, do: :undefined, else: callback

    :gen_smtp_client.send(
      {email.from, email.to, message},
      config,
      callback
    )

    :ok
  end

  @spec send_batch([Email.t()], domain :: String.t()) :: {:ok, [Email.t()]} | {:error, term()}
  def send_batch(emails, domain) do
    with {:ok, socket} <- connect(relay: domain, hostname: domain),
         {:ok, results} <- send_bulk(emails, socket),
         :ok <- disconnect(socket) do
      {:ok, results}
    else
      error -> {:error, error}
    end
  end

  @spec connect(opts :: Keyword.t()) ::
          {:ok, term()} | {:error, term()}
  def connect(opts \\ []) do
    config =
      opts
      |> SmtpConfig.new()
      |> SmtpConfig.to_keyword_list()

    case :gen_smtp_client.open(config) do
      {:ok, socket} ->
        {:ok, socket}

      {:error, _type, details} ->
        {:error, details}
    end
  end

  def disconnect(socket) do
    :gen_smtp_client.close(socket)
  end

  @doc """
  Delivers email over a persistent socket connection, this can be used when
  PIPELINING on the receiving server is available.
  """
  @spec send_bulk([Email.t()], term(), acc :: list()) ::
          {:ok, [Email.t()]} | {:error, term(), [Email.t()]}
  def send_bulk(emails, socket, acc \\ []) do
    deliver(emails, socket, acc)
  end

  defp deliver([], socket, acc) do
    :gen_smtp_client.close(socket)
    {:ok, acc}
  end

  defp deliver([email | rest], socket, acc) do
    message = Render.encode(email)

    response =
      :gen_smtp_client.deliver(
        socket,
        {email.from, email.to, message}
      )

    case response do
      {:ok, receipt} ->
        email = Email.handle_delivery(email, receipt)
        acc = [email | acc]

        deliver(rest, socket, acc)

      {:error, reason} ->
        email = Email.handle_failure(email, reason)
        acc = [email | acc]

        deliver(rest, socket, acc)
    end
  end
end
