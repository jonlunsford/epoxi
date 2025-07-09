defmodule Epoxi.NodeRegistry do
  @moduledoc """
  Cluster-wide registry for tracking node information, pipelines, and IP addresses.

  This GenServer provides state management for the distributed cluster, delegating
  all business logic to specialized modules. It maintains cluster state and
  coordinates node lifecycle events.

  Key responsibilities:
  - Maintain cluster state and node information
  - Monitor node up/down events
  - Delegate to business logic modules
  - Provide unified API for cluster operations
  """

  use GenServer
  require Logger

  alias Epoxi.{Cluster, Node, NodeManager, IpManager, PipelineManager}

  defstruct cluster: %Cluster{}, node_metadata: %{}, ip_weights: %{}

  @type node_name :: atom()
  @type ip_address :: String.t()
  @type pool_name :: atom()
  @type ip_weight :: non_neg_integer()

  @type t :: %__MODULE__{
          cluster: Cluster.t(),
          node_metadata: %{node_name() => NodeManager.node_metadata()},
          ip_weights: %{ip_address() => ip_weight()}
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Node Management API

  @doc """
  Register a node.
  """
  @spec register_node(node_name()) :: :ok
  def register_node(node_name) do
    register_node(node_name, %{})
  end

  @doc """
  Register a node with metadata.
  """
  @spec register_node(node_name(), NodeManager.node_metadata()) :: :ok
  def register_node(node_name, metadata) do
    GenServer.call(__MODULE__, {:register_node, node_name, metadata})
  end

  @doc """
  Unregister a node from the cluster.
  """
  @spec unregister_node(node_name()) :: :ok
  def unregister_node(node_name) do
    GenServer.call(__MODULE__, {:unregister_node, node_name})
  end

  @doc """
  Get node information.
  """
  @spec get_node(node_name()) :: {:ok, Node.t()} | {:error, :not_found}
  def get_node(node_name) do
    GenServer.call(__MODULE__, {:get_node, node_name})
  end

  @doc """
  List all nodes in the cluster.
  """
  @spec list_nodes() :: [Node.t()]
  def list_nodes() do
    GenServer.call(__MODULE__, :list_nodes)
  end

  @doc """
  List all nodes in a specific pool.
  """
  @spec list_nodes_in_pool(pool_name()) :: [Node.t()]
  def list_nodes_in_pool(pool_name) do
    GenServer.call(__MODULE__, {:list_nodes_in_pool, pool_name})
  end

  @doc """
  Update node metadata.
  """
  @spec update_node_metadata(node_name(), NodeManager.node_metadata()) :: :ok
  def update_node_metadata(node_name, metadata) do
    GenServer.cast(__MODULE__, {:update_node_metadata, node_name, metadata})
  end

  @doc """
  Select optimal nodes based on strategy and criteria.
  """
  @spec select_optimal_nodes(NodeManager.node_selection_strategy(), map()) :: [Node.t()]
  def select_optimal_nodes(strategy, criteria \\ %{}) do
    GenServer.call(__MODULE__, {:select_optimal_nodes, strategy, criteria})
  end

  # IP Management API

  @doc """
  Allocate IP addresses to emails.
  """
  @spec allocate_ips([Epoxi.Email.t()], pool_name(), IpManager.allocation_strategy()) :: [
          Epoxi.Email.t()
        ]
  def allocate_ips(emails, pool_name, strategy \\ :weighted) do
    GenServer.call(__MODULE__, {:allocate_ips, emails, pool_name, strategy})
  end

  @doc """
  Get all IPs available in a specific pool.
  """
  @spec get_pool_ips(pool_name()) :: [ip_address()]
  def get_pool_ips(pool_name) do
    GenServer.call(__MODULE__, {:get_pool_ips, pool_name})
  end

  @doc """
  Get all available IPs for a specific node.
  """
  @spec get_node_ips(node_name()) :: [ip_address()]
  def get_node_ips(node_name) do
    GenServer.call(__MODULE__, {:get_node_ips, node_name})
  end

  @doc """
  Find which node owns a specific IP address.
  """
  @spec find_ip_owner(ip_address()) :: {:ok, node_name()} | {:error, :not_found}
  def find_ip_owner(ip_address) do
    GenServer.call(__MODULE__, {:find_ip_owner, ip_address})
  end

  @doc """
  Get all available IPs across the entire cluster.
  """
  @spec get_all_cluster_ips() :: [{ip_address(), node_name()}]
  def get_all_cluster_ips() do
    GenServer.call(__MODULE__, :get_all_cluster_ips)
  end

  @doc """
  Set the weight for a specific IP address.
  """
  @spec set_ip_weight(ip_address(), ip_weight()) :: :ok
  def set_ip_weight(ip_address, weight) do
    GenServer.cast(__MODULE__, {:set_ip_weight, ip_address, weight})
  end

  @doc """
  Get the weight for a specific IP address.
  """
  @spec get_ip_weight(ip_address()) :: ip_weight()
  def get_ip_weight(ip_address) do
    GenServer.call(__MODULE__, {:get_ip_weight, ip_address})
  end

  # Pipeline Management API

  @doc """
  Register a pipeline with a specific node.
  """
  @spec register_pipeline(node_name(), Node.pipeline_info()) :: :ok
  def register_pipeline(node_name, pipeline_info) do
    GenServer.call(__MODULE__, {:register_pipeline, node_name, pipeline_info})
  end

  @doc """
  Unregister a pipeline from a specific node.
  """
  @spec unregister_pipeline(node_name(), atom()) :: :ok
  def unregister_pipeline(node_name, pipeline_name) do
    GenServer.call(__MODULE__, {:unregister_pipeline, node_name, pipeline_name})
  end

  @doc """
  Find all pipelines running across the cluster.
  """
  @spec find_all_pipelines() :: %{node_name() => [Node.pipeline_info()]}
  def find_all_pipelines() do
    GenServer.call(__MODULE__, :find_all_pipelines)
  end

  @doc """
  Find pipelines by routing key across the cluster.
  """
  @spec find_pipelines_by_routing_key(String.t()) :: %{node_name() => [Node.pipeline_info()]}
  def find_pipelines_by_routing_key(routing_key) do
    GenServer.call(__MODULE__, {:find_pipelines_by_routing_key, routing_key})
  end

  @doc """
  Find a node that can handle a specific routing key.
  """
  @spec find_node_for_routing_key(String.t()) :: {:ok, Node.t()} | {:error, :not_found}
  def find_node_for_routing_key(routing_key) do
    GenServer.call(__MODULE__, {:find_node_for_routing_key, routing_key})
  end

  @doc """
  Get all pipelines running on a specific node.
  """
  @spec get_node_pipelines(node_name()) :: [Node.pipeline_info()]
  def get_node_pipelines(node_name) do
    GenServer.call(__MODULE__, {:get_node_pipelines, node_name})
  end

  @doc """
  Select optimal node for starting a new pipeline.
  """
  @spec select_optimal_node_for_pipeline(pool_name(), PipelineManager.selection_strategy()) ::
          {:ok, Node.t()} | {:error, :no_nodes_available}
  def select_optimal_node_for_pipeline(ip_pool, strategy \\ :least_pipelines) do
    GenServer.call(__MODULE__, {:select_optimal_node_for_pipeline, ip_pool, strategy})
  end

  @doc """
  Get comprehensive pipeline statistics for the cluster.
  """
  @spec get_pipeline_stats() :: map()
  def get_pipeline_stats() do
    GenServer.call(__MODULE__, :get_pipeline_stats)
  end

  @doc """
  Force refresh of cluster state.
  """
  @spec refresh() :: :ok
  def refresh() do
    GenServer.cast(__MODULE__, :refresh)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    :ok = :net_kernel.monitor_nodes(true, [:nodedown_reason])

    state = %__MODULE__{
      cluster: Cluster.init()
    }

    {:ok, state}
  end

  # Node Management Callbacks

  @impl true
  def handle_call({:register_node, node_name, metadata}, _from, state) do
    node = Node.from_node(node_name)
    updated_cluster = NodeManager.register_node(state.cluster, node)
    updated_metadata = Map.put(state.node_metadata, node_name, metadata)

    new_state = %{state | cluster: updated_cluster, node_metadata: updated_metadata}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister_node, node_name}, _from, state) do
    node = Node.new(name: node_name)
    updated_cluster = NodeManager.unregister_node(state.cluster, node)
    updated_metadata = Map.delete(state.node_metadata, node_name)

    new_state = %{state | cluster: updated_cluster, node_metadata: updated_metadata}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_node, node_name}, _from, state) do
    result = NodeManager.get_node(state.cluster, node_name)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_nodes, _from, state) do
    nodes = NodeManager.list_nodes(state.cluster)
    {:reply, nodes, state}
  end

  @impl true
  def handle_call({:list_nodes_in_pool, pool_name}, _from, state) do
    nodes = NodeManager.list_nodes_in_pool(state.cluster, pool_name)
    {:reply, nodes, state}
  end

  @impl true
  def handle_call({:select_optimal_nodes, strategy, criteria}, _from, state) do
    nodes = NodeManager.select_optimal_nodes(state.cluster, strategy, criteria)
    {:reply, nodes, state}
  end

  # IP Management Callbacks

  @impl true
  def handle_call({:allocate_ips, emails, pool_name, strategy}, _from, state) do
    allocated_emails =
      IpManager.allocate_ips(emails, state.cluster, state.ip_weights, pool_name, strategy)

    {:reply, allocated_emails, state}
  end

  @impl true
  def handle_call({:get_pool_ips, pool_name}, _from, state) do
    pool_ips = IpManager.get_pool_ips(state.cluster, pool_name)
    {:reply, pool_ips, state}
  end

  @impl true
  def handle_call({:get_node_ips, node_name}, _from, state) do
    node_ips = IpManager.get_node_ips(state.cluster, node_name)
    {:reply, node_ips, state}
  end

  @impl true
  def handle_call({:find_ip_owner, ip_address}, _from, state) do
    result = IpManager.find_ip_owner(state.cluster, ip_address)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_all_cluster_ips, _from, state) do
    all_ips = IpManager.get_all_cluster_ips(state.cluster)
    {:reply, all_ips, state}
  end

  @impl true
  def handle_call({:get_ip_weight, ip_address}, _from, state) do
    weight = IpManager.get_ip_weight(state.ip_weights, ip_address)
    {:reply, weight, state}
  end

  # Pipeline Management Callbacks

  @impl true
  def handle_call({:register_pipeline, node_name, pipeline_info}, _from, state) do
    updated_cluster = PipelineManager.register_pipeline(state.cluster, node_name, pipeline_info)
    new_state = %{state | cluster: updated_cluster}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister_pipeline, node_name, pipeline_name}, _from, state) do
    updated_cluster = PipelineManager.unregister_pipeline(state.cluster, node_name, pipeline_name)
    new_state = %{state | cluster: updated_cluster}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:find_all_pipelines, _from, state) do
    pipelines = PipelineManager.find_all_pipelines(state.cluster)
    {:reply, pipelines, state}
  end

  @impl true
  def handle_call({:find_pipelines_by_routing_key, routing_key}, _from, state) do
    pipelines = PipelineManager.find_pipelines_by_routing_key(state.cluster, routing_key)
    {:reply, pipelines, state}
  end

  @impl true
  def handle_call({:find_node_for_routing_key, routing_key}, _from, state) do
    result = PipelineManager.find_node_for_routing_key(state.cluster, routing_key)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_node_pipelines, node_name}, _from, state) do
    pipelines = PipelineManager.get_node_pipelines(state.cluster, node_name)
    {:reply, pipelines, state}
  end

  @impl true
  def handle_call({:select_optimal_node_for_pipeline, ip_pool, strategy}, _from, state) do
    result = PipelineManager.select_optimal_node_for_pipeline(state.cluster, ip_pool, strategy)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_pipeline_stats, _from, state) do
    stats = PipelineManager.get_pipeline_stats(state.cluster)
    {:reply, stats, state}
  end

  # Cast Callbacks

  @impl true
  def handle_cast(:refresh, state) do
    updated_cluster = Cluster.get_current_state(state.cluster)
    new_state = %{state | cluster: updated_cluster}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_node_metadata, node_name, metadata}, state) do
    # Update metadata in state only - cluster doesn't store metadata
    updated_metadata = Map.put(state.node_metadata, node_name, metadata)

    new_state = %{state | node_metadata: updated_metadata}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:set_ip_weight, ip_address, weight}, state) do
    updated_weights = IpManager.set_ip_weight(state.ip_weights, ip_address, weight)
    new_state = %{state | ip_weights: updated_weights}
    {:noreply, new_state}
  end

  # Info Callbacks

  @impl true
  def handle_info({:nodeup, node_name, _info}, state) do
    Logger.info("Node #{node_name} joined cluster, updating registry")

    node = Node.from_node(node_name)
    updated_cluster = NodeManager.register_node(state.cluster, node)

    new_state = %{state | cluster: updated_cluster}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:nodedown, node_name, reason}, state) do
    Logger.info("Node #{node_name} left cluster (reason: #{inspect(reason)}), updating registry")

    node = Node.new(name: node_name)
    updated_cluster = NodeManager.unregister_node(state.cluster, node)
    updated_metadata = Map.delete(state.node_metadata, node_name)

    new_state = %{state | cluster: updated_cluster, node_metadata: updated_metadata}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("NodeRegistry received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :net_kernel.monitor_nodes(false)
    :ok
  end
end
