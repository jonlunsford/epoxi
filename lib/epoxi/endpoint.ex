defmodule Epoxi.Endpoint do
  require Logger
  import Plug.Conn
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(Plug.Telemetry, event_prefix: [:epoxi, :endpoint])
  plug(Plug.Parsers, parsers: [:json], json_decoder: JSON)
  plug(:dispatch)

  def init(options) do
    options
  end

  get "/ping" do
    send_resp(conn, 200, "pong!")
  end

  post "/messages" do
    {status, body} =
      case conn.body_params do
        %{"message" => message} ->
          # TODO: Validate JSON payload
          emails = Epoxi.JSONDecoder.decode(message)
          OffBroadwayMemory.Buffer.push(:inbox, emails)

          {200, "Message queued"}

        _ ->
          {400, "Bad Request"}
      end

    send_resp(conn, status, body)
  end

  match _ do
    send_resp(conn, 404, "oops... Nothing here :(")
  end
end
