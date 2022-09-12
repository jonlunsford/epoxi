defmodule Epoxi do
  @moduledoc """
  Epoxi - A complete mail server
  """

  alias Epoxi.Render
  alias Epoxi.Parsing
  alias Epoxi.Utils

  defprotocol Adapter do
    @moduledoc "Protocol for sending adapters to implement"
    def send_blocking(context, email, message)
    #def deliver(config, email, message)
  end

  defprotocol Composer do
    @moduledoc "Protocol for composers to impliment"
    def compile_part(config, mode, email)
  end

  def send_blocking(email, context) do
    # TODO: pre-cache mx records for popular domains
    {_priority, relay} =
      Parsing.get_hostname(email.to)
      |> Utils.mx_lookup()
      |> List.first()

    message = Render.encode(email)
    config = %{context.config | relay: relay}

    case Adapter.send_blocking(config, email, message) do
      {:error, reason} ->
        IO.inspect(reason, label: :error_sending)

      {:ok, response} ->
        IO.inspect(response, label: :success_sending)
    end
  end
end
