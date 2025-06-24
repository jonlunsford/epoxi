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
    node =
      Epoxi.Cluster.init()
      |> Epoxi.Cluster.find_pool(pool)
      # TODO: Use algos (round robbin, etc) to select node in pool.
      |> hd()

    case Epoxi.Node.route_cast(node, Epoxi.Queue, :enqueue_many, [:inbox, emails]) do
      :ok -> {200, "Messages queued in the #{pool} pool"}
      {:ok, :message_sent_async} -> {200, "Messages queued in the #{pool} pool"}
      {:error, reason} -> {400, reason}
    end
  end
end
