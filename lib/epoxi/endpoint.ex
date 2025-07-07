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
        %{"message" => message} = params ->
          ip_pool =
            params
            |> Map.get("ip_pool", "default")
            |> String.to_atom()

          emails = Epoxi.JSONDecoder.decode(message)

          route_to_node(emails, ip_pool)

        _ ->
          {400, "Bad Request"}
      end

    send_resp(conn, status, body)
  end

  match _ do
    send_resp(conn, 404, "oops... Nothing here :(")
  end

  defp route_to_node(emails, pool) do
    case Epoxi.Email.Router.route_emails(emails, pool) do
      {:ok, summary} ->
        message = build_success_message(summary, pool)
        {200, message}
      
      {:error, reason} ->
        Logger.error("Failed to route emails: #{inspect(reason)}")
        {400, "Failed to route emails: #{reason}"}
    end
  end
  
  defp build_success_message(summary, pool) do
    "Successfully routed #{summary.total_emails} emails in #{summary.total_batches} batches to #{pool} pool. " <>
    "#{summary.new_pipelines_started} new pipelines started."
  end
end
