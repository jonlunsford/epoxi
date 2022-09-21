defmodule Epoxi do
  require Logger
  @moduledoc """
  Epoxi - A complete mail server
  """

  alias Epoxi.Render

  defprotocol Adapter do
    @doc "Send an email and block waiting for the reply."
    def send_blocking(context, email, message)

    @doc "Send a non-blocking email"
    def send(context, email, message)

    @doc "send an email over a persistent socket"
    def deliver(emails, context)
  end

  def send_blocking(email, context) do
    message = encode_message(email, context)

    case Adapter.send_blocking(context, email, message) do
      {:error, reason} ->
        Logger.debug("Error sending: #{IO.inspect(reason)}")

      {:ok, response} ->
        Logger.debug("Success sending: #{IO.inspect(response)}")
    end
  end

  def send(email, context) do
    message = encode_message(email, context)

    case Adapter.send(context, email, message) do
      {:error, reason} ->
        Logger.debug("Error sending: #{IO.inspect(reason)}")

      {:ok, pid} ->
        Logger.debug("Message queued: #{IO.inspect(pid)}")
    end
  end

  def deliver(emails, context) do
    case Adapter.deliver(emails, context) do
      {:error, reason} ->
        Logger.debug("Error delivering: #{IO.inspect(reason)}")

      {:ok, receipt} ->
        Logger.debug("Messages queued: #{IO.inspect(receipt)}")
    end
  end

  defp encode_message(%Epoxi.Email{} = email, context) do
    email
    |> Render.encode(context.compiler)
  end
end
