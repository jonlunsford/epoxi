defmodule Epoxi do
  @moduledoc """
  Epoxi - A complete mail server
  """

  alias Epoxi.Render

  defprotocol Adapter do
    @doc "Adapters to implement to send a blocking email."
    def send_blocking(context, email, message)
  end

  def send_blocking(email, context) do
    message = Render.encode(email)

    case Adapter.send_blocking(context, email, message) do
      {:error, reason} ->
        IO.inspect(reason, label: :error_sending)

      {:ok, response} ->
        IO.inspect(response, label: :success_sending)
    end
  end
end
