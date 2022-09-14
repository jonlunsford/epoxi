defmodule Epoxi do
  @moduledoc """
  Epoxi - A complete mail server
  """

  alias Epoxi.Render
  alias Epoxi.Parsing
  alias Epoxi.Utils

  def send_blocking(email, context) do
    from_hostname = Parsing.get_hostname(email.from)

    # TODO: pre-cache/lookup mx records for popular domains
    {_priority, relay} =
      Parsing.get_hostname(email.to)
      |> Utils.mx_lookup()
      |> List.first()

    message = Render.encode(email)
    config = %{context.config | relay: relay, hostname: from_hostname}

    case Epoxi.Adapter.send_blocking(config, email, message) do
      {:error, reason} ->
        IO.inspect(reason, label: :error_sending)

      {:ok, response} ->
        IO.inspect(response, label: :success_sending)
    end
  end
end
