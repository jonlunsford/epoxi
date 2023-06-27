defmodule Epoxi do
  require Logger

  @moduledoc """
  Epoxi - A complete mail server
  """

  alias Epoxi.{Render, Context, Email}

  defprotocol Adapter do
    @doc "Send an email and block waiting for the reply."
    @spec send_blocking(
            context :: Context.LocalSmtp.t() | Context.ExternalSmtp.t(),
            email :: Email.t(),
            message :: binary()
          ) ::
            {:ok, binary()} | {:error, binary()} | {:error, binary(), binary()}
    def send_blocking(context, email, message)

    @doc "Send a non-blocking email"
    @spec send(
            context :: Context.LocalSmtp.t() | Context.ExternalSmtp.t(),
            email :: Email.t(),
            message :: binary()
          ) ::
            {:ok, pid()} | {:error, binary()}
    def send(context, email, message)

    @doc "send a a batch emails over a persistent socket"
    @spec deliver(
            context :: Context.LocalSmtp.t() | Context.ExternalSmtp.t(),
            emails :: [Email.t()]
          ) ::
            {:ok, :all_queued} | {:error, binary()}
    def deliver(emails, context)
  end

  def send_blocking(email, context) do
    message = encode_message(email, context)

    case Adapter.send_blocking(context, email, message) do
      {:error, reason} ->
        {:error, reason}

      {:error, _, reason} ->
        {:error, reason}

      {:ok, response} ->
        {:ok, response}
    end
  end

  def send(email, context) do
    message = encode_message(email, context)

    case Adapter.send(context, email, message) do
      {:error, reason} ->
        {:error, reason}

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  def deliver(emails, context) do
    case Adapter.deliver(context, emails) do
      {:ok, receipt} ->
        {:ok, receipt}

      {error, reason} ->
        {error, reason}
    end
  end

  defp encode_message(%Epoxi.Email{} = email, context) do
    email
    |> Render.encode(context.compiler)
  end
end
