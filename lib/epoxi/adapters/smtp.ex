defmodule Epoxi.Adapters.SMTP do
  require Logger
  @moduledoc """
  Delivers mail to SMTP servers
  """

  alias Epoxi.SmtpConfig

  @doc """
  Sends an email and blocks until a response is received. Returns an error tuple
  or a binary that is the send receipt returned from the receiving server
  """
  def send_blocking(%SmtpConfig{} = config, email, message) do
    config = Map.to_list(config)

    response =
      :gen_smtp_client.send_blocking(
        {email.from, email.to, message},
        config
      )

    case response do
      {:error, _, reason} -> {:error, reason, response}
      {:error, reason} -> {:error, reason, response}
      _ -> {:ok, response}
    end
  end

  @doc """
  Send a non-blocking email via a spawned_linked process
  """
  def send(%SmtpConfig{} = config, email, message) do
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
  def deliver(socket, email, message) do
    :gen_smtp_client.deliver(
      socket,
      {email.from, email.to, message}
    )
  end

  defp handle_send_result({:ok, receipt}) do
    # TODO: Handle send results async and supervised
    Logger.debug("Received send result: {:ok, #{IO.inspect(receipt)}}")
    :ok
  end

  defp handle_send_result({:error, _, reason}) do
    Logger.debug("Received send result: {:error, #{IO.inspect(reason)}}")
    :error
  end

  defp handle_send_result({:exit, reason}) do
    Logger.debug("Received send result: {:exit, #{IO.inspect(reason)}}")
    :exit
  end
end
