defmodule Epoxi.Endpoint do
  require Logger
  import Plug.Conn
  use Plug.Router

  alias Epoxi.DKIM.Manager

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

  get "/admin/pipelines" do
    stats = Epoxi.PipelineMonitor.get_cluster_stats()
    send_resp(conn, 200, JSON.encode!(stats))
  end

  get "/admin/pipelines/health" do
    health_results = Epoxi.PipelineMonitor.health_check_all()
    send_resp(conn, 200, JSON.encode!(health_results))
  end

  get "/admin/pipelines/:routing_key" do
    routing_key = conn.path_params["routing_key"]
    health_results = Epoxi.PipelineMonitor.health_check_routing_key(routing_key)
    send_resp(conn, 200, JSON.encode!(health_results))
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

  # DKIM Management Endpoints

  post "/admin/dkim" do
    required_fields = ["tenant_id", "domain", "selector", "private_key"]
    params = conn.body_params

    result =
      with {:ok, attrs} <- validate_required_fields(params, required_fields),
           {:ok, config} <- Manager.create(attrs) do
        {:ok, %{success: true, domain: config.domain}}
      end

    send_json(conn, result, created: 201, conflict: 409)
  end

  get "/admin/dkim" do
    configs = Manager.list()
    send_json(conn, {:ok, configs})
  end

  get "/admin/dkim/:domain" do
    domain = conn.path_params["domain"]
    result = Manager.get(domain)
    send_json(conn, result)
  end

  put "/admin/dkim/:domain" do
    domain = conn.path_params["domain"]
    attrs = parse_update_attrs(conn.body_params)
    result = Manager.update(domain, attrs)
    send_json(conn, result)
  end

  delete "/admin/dkim/:domain" do
    domain = conn.path_params["domain"]
    :ok = Manager.remove(domain)
    send_json(conn, {:ok, %{success: true, domain: domain}})
  end

  match _ do
    send_resp(conn, 404, "oops... Nothing here :(")
  end

  # Private helper functions

  defp validate_required_fields(params, required_fields) do
    missing = Enum.filter(required_fields, &(not Map.has_key?(params, &1)))

    if Enum.empty?(missing) do
      attrs =
        params
        |> Map.take(required_fields ++ ["algorithm", "canonicalization", "status"])
        |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
        |> maybe_atomize_status()

      {:ok, attrs}
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp parse_update_attrs(params) do
    params
    |> Map.take(["selector", "private_key", "algorithm", "canonicalization", "status"])
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> maybe_atomize_status()
  end

  defp maybe_atomize_status(%{status: status} = attrs) when is_binary(status) do
    %{attrs | status: String.to_existing_atom(status)}
  rescue
    ArgumentError -> attrs
  end

  defp maybe_atomize_status(attrs), do: attrs

  defp send_json(conn, result, status_codes \\ []) do
    {status, body} = format_response(result, status_codes)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, JSON.encode!(body))
  end

  defp format_response({:ok, data}, status_codes) do
    status = Keyword.get(status_codes, :created, 200)
    {status, data}
  end

  defp format_response({:error, :not_found}, _status_codes) do
    {404, %{error: "Resource not found"}}
  end

  defp format_response({:error, :already_exists}, status_codes) do
    status = Keyword.get(status_codes, :conflict, 409)
    {status, %{error: "Resource already exists"}}
  end

  defp format_response({:error, {:missing_fields, fields}}, _status_codes) do
    {400, %{error: "Missing required fields", fields: fields}}
  end

  defp format_response({:error, reason}, _status_codes) do
    {400, %{error: "Invalid request: #{reason}"}}
  end

  defp route_to_node(emails, pool) do
    {:ok, summary} = Epoxi.Email.Router.route_emails(emails, pool)
    message = build_success_message(summary, pool)
    {200, message}
  end

  defp build_success_message(summary, pool) do
    "Successfully routed #{summary.total_emails} emails in #{summary.total_batches} batches to #{pool} pool. " <>
      "#{summary.new_pipelines_started} new pipelines started."
  end
end
