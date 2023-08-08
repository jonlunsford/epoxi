defmodule Epoxi do
  require Logger

  @moduledoc """
  Epoxi - A complete mail server
  """

  def send_blocking(email, context) do
    context().send_blocking(email, context)
  end

  def send(email, context) do
    context().send(email, context)
  end

  def deliver(emails, context) do
    context().deliver(emails, context)
  end

  defp context(), do: Application.get_env(:epoxi, :context_module, Epoxi.Context.ExternalSmtp)
end
