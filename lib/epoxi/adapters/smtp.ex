defmodule Epoxi.Adapters.SMTP do
  @moduledoc """
  Delivers mail to SMTP servers
  """

  alias Epoxi.SmtpConfig

  @doc """
  Sends an email and blocks until a response is received. Returns an error tuple
  or a binary that is the send receipt returned from the receiving server
  """
  def send_blocking(email, %SmtpConfig{} = config) do
    message = Epoxi.Render.encode(email)
    config = Map.to_list(config)

    :gen_smtp_client.send_blocking(
      {email.from, email.to, message},
      config
    )
  end

  @doc """
  Send a non-blocking email via a spawned_linked process
  """
  def send(email, %SmtpConfig{} = config) do
    message = Epoxi.Render.encode(email)
    config = Map.to_list(config)

    :gen_smtp_client.send(
      {email.from, email.to, message},
      config,
      &handle_send_result/1
    )
  end

  @doc """
  Delivers email over an existing socket connection, this can be used when
  PIPELINING on the receiving server is available.
  """
  def deliver([], _socket) do
    {:ok, :all_queued}
  end

  def deliver([email | rest], socket) do
    message = Epoxi.Render.encode(email)

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

  defp handle_send_result({:ok, receipt}) do
    {:ok, receipt}
  end

  defp handle_send_result({:error, type, reason}) do
    {:error, type, reason}
  end

  defp handle_send_result({:exit, reason}) do
    {:exit, reason}
  end
end
