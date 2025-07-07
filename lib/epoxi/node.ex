defmodule Epoxi.Node do
  @moduledoc """
  Represents and manages Epoxi.Node instances within a distributed cluster.

  This module provides functionality for:
  - Creating and managing node representations
  - Facilitating inter-node communication via RPC calls
  - Monitoring node state and network information
  - Handling both synchronous and asynchronous operations across nodes

  It serves as a key component for maintaining distributed functionality in the Epoxi system.
  """
  defstruct [
    :name,
    :emails_queued,
    :last_seen,
    :ip_addresses,
    ip_pool: :default,
    status: :unknown,
    pipelines: []
  ]

  require Logger

  @type node_status :: :up | :down | :unknown
  @type ip_address :: String.t()

  @type t :: %__MODULE__{
          emails_queued: non_neg_integer(),
          name: atom(),
          status: node_status(),
          ip_addresses: [ip_address()],
          ip_pool: atom(),
          last_seen: Calendar.datetime(),
          pipelines: [pipeline_info()]
        }

  @type pipeline_info :: %{
          name: atom(),
          routing_key: String.t() | nil,
          pid: pid(),
          policy: Epoxi.Queue.PipelinePolicy.t() | nil,
          started_at: DateTime.t()
        }

  def new(attrs \\ []) do
    struct(Epoxi.Node, attrs)
  end

  @spec from_node(node()) :: t()
  def from_node(node) do
    new(name: node)
    |> state()
  end

  @spec current :: t()
  def current do
    Node.self()
    |> from_node()
  end

  @spec route_cast(
          target_node :: t(),
          mod :: module(),
          fun :: atom(),
          args :: list(any())
        ) :: any()
  def route_cast(%Epoxi.Node{} = target_node, mod, fun, args) do
    case local?(target_node) do
      true -> apply(mod, fun, args)
      false -> erpc_cast(target_node, mod, fun, args)
    end
  end

  @spec route_call(
          target_node :: t(),
          mod :: module(),
          fun :: atom(),
          args :: list(any())
        ) :: any()
  def route_call(%Epoxi.Node{} = target_node, mod, fun, args) do
    case local?(target_node) do
      true -> apply(mod, fun, args)
      false -> erpc_call(target_node, mod, fun, args)
    end
  end

  @spec state(target_node :: t()) :: t()
  def state(%Epoxi.Node{} = node) do
    case local?(node) do
      true ->
        put_state(node, %{status: :up, last_seen: DateTime.utc_now()})

      false ->
        erpc_call(node, Epoxi.Node, :state, [node])
    end
  end

  @spec interfaces(target_node :: t()) :: {:ok, [ip_address()]} | {:error, term()}
  def interfaces(%Epoxi.Node{} = target_node) do
    case route_call(target_node, :inet, :getifaddrs, []) do
      {:ok, interfaces} ->
        result = format_interface_addresses(interfaces)
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Registers a pipeline on the current node.
  """
  @spec register_pipeline(pipeline_info()) :: :ok
  def register_pipeline(pipeline_info) do
    :ets.insert_new(:epoxi_node_pipelines, {pipeline_info.name, pipeline_info})
    :ok
  end

  @doc """
  Unregisters a pipeline from the current node.
  """
  @spec unregister_pipeline(atom()) :: :ok
  def unregister_pipeline(pipeline_name) do
    :ets.delete(:epoxi_node_pipelines, pipeline_name)
    :ok
  end

  @doc """
  Gets all pipelines running on the current node.
  """
  @spec get_pipelines() :: [pipeline_info()]
  def get_pipelines do
    case :ets.whereis(:epoxi_node_pipelines) do
      :undefined ->
        # Create table if it doesn't exist
        :ets.new(:epoxi_node_pipelines, [:named_table, :public, :set])
        []

      _table ->
        :ets.tab2list(:epoxi_node_pipelines)
        |> Enum.map(fn {_name, pipeline_info} -> pipeline_info end)
    end
  end

  @doc """
  Gets all pipelines running on a specific node.
  """
  @spec get_pipelines(target_node :: t()) :: [pipeline_info()]
  def get_pipelines(%Epoxi.Node{} = target_node) do
    route_call(target_node, __MODULE__, :get_pipelines, [])
  end

  @doc """
  Finds pipelines by routing key on the current node.
  """
  @spec find_pipelines_by_routing_key(String.t()) :: [pipeline_info()]
  def find_pipelines_by_routing_key(routing_key) do
    get_pipelines()
    |> Enum.filter(fn pipeline -> pipeline.routing_key == routing_key end)
  end

  @doc """
  Finds pipelines by routing key on a specific node.
  """
  @spec find_pipelines_by_routing_key(target_node :: t(), routing_key :: String.t()) :: [
          pipeline_info()
        ]
  def find_pipelines_by_routing_key(%Epoxi.Node{} = target_node, routing_key) do
    route_call(target_node, __MODULE__, :find_pipelines_by_routing_key, [routing_key])
  end

  defp local?(%Epoxi.Node{name: node_name}) do
    Node.self() == node_name
  end

  @spec erpc_call(target_node :: t(), mod :: module(), fun :: atom(), args :: list(any())) ::
          any()
  defp erpc_call(%Epoxi.Node{name: node_name}, mod, fun, args) do
    start_time = System.monotonic_time()

    result = :erpc.call(node_name, mod, fun, args)
    record_routing_telemetry(self(), node_name, start_time, result)
    result
  end

  @spec erpc_cast(target_node :: t(), mod :: module(), fun :: atom(), args :: list(any())) ::
          any()
  defp erpc_cast(%Epoxi.Node{name: node_name}, mod, fun, args) do
    start_time = System.monotonic_time()

    result = :erpc.cast(node_name, mod, fun, args)
    record_routing_telemetry(self(), node_name, start_time, result)
    result
  end

  defp put_state(%Epoxi.Node{} = node, additional_state) do
    {:ok, ips} = interfaces(node)
    pipelines = get_pipelines()

    node
    |> Map.put(:ip_addresses, ips)
    |> Map.put(:pipelines, pipelines)
    |> Map.merge(additional_state)
  end

  defp record_routing_telemetry(source_node, target_node, start_time, result) do
    end_time = System.monotonic_time()
    duration = end_time - start_time

    :telemetry.execute(
      [:epoxi, :router, :route, :count],
      %{count: 1},
      %{source_node: source_node, target_node: target_node, result: result}
    )

    :telemetry.execute(
      [:epoxi, :router, :route, :latency],
      %{duration: duration},
      %{source_node: source_node, target_node: target_node}
    )
  end

  defp format_interface_addresses(interfaces) do
    interfaces
    |> Enum.flat_map(fn {_if_name, if_opts} ->
      addr = Keyword.get(if_opts, :addr)

      case addr do
        {a, b, c, d} -> ["#{a}.#{b}.#{c}.#{d}"]
        _ -> []
      end
    end)
  end
end
