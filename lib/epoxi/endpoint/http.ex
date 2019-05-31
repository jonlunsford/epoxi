defmodule Epoxi.Endpoint.HTTP do
  use Plug.Router

  plug Plug.Logger
  plug :match
  plug Plug.Telemetry, event_prefix: [:epoxi, :endpoint]
  plug :dispatch

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def init(options) do
    options
  end

  def start_link(_) do
    # NOTE: This starts Cowboy listening on the default port of 4000
    {:ok, _} = Plug.Adapters.Cowboy.http(__MODULE__, [])
  end

  post "/send" do
    :ok =
      case Plug.Conn.read_body(conn) do
        {:ok, data, _body} ->
          inbox = Epoxi.Queues.Supervisor.available_inbox()
          Epoxi.Queues.Inbox.enqueue(inbox, data)
        _ -> {422, missing_data()}
      end
    send_resp(conn, 200, "enqueued")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp missing_data do
    "Missing a `data` key!"
  end
end
