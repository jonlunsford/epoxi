defmodule Epoxi do
  require Logger

  @moduledoc """
  Epoxi - A complete mail server
  """

  alias Epoxi.{Context, Email}

  defprotocol Adapter do
    @doc "Send an email and block waiting for the reply."
    @spec send_blocking(Context.t(), Email.t()) :: {:ok, binary()} | {:error, term()}
    def send_blocking(email, context)

    @doc "Send a non-blocking email"
    @spec send(Context.t(), Email.t()) :: :ok | {:error, term()}
    def send(email, context)

    @doc "send a of batch emails over a persistent socket"
    @spec deliver(Context.t(), [Email.t()]) :: {:ok, :all_queued} | {:error, term()}
    def deliver(emails, context)
  end

  def send_blocking(email, context) do
    Adapter.send_blocking(email, context)
  end

  def send(email, context) do
    Adapter.send(email, context)
  end

  def deliver(emails, context) do
    Adapter.deliver(emails, context)
  end
end
