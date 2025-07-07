defmodule Epoxi.Cluster do
  @moduledoc """
  Provides functionality for managing and interacting with a cluster of Epoxi.Node instances.

  This module offers capabilities for:
  - Creating and managing cluster representations
  - Tracking connected nodes within the cluster
  - Retrieving aggregated state information from all nodes
  - Finding specific nodes within the cluster
  - Aggregating IP addresses into logical pools across the cluster

  It serves as a central component for managing distributed node operations in the Epoxi system.
  """

  alias Epoxi.Cluster

  defstruct node_count: 0, nodes: [], ip_pools: %{default: %{}}

  @type ip_address :: String.t()
  @type pool_name :: atom()
  @type pipeline_stats :: %{
          total_pipelines: non_neg_integer(),
          nodes_with_pipelines: non_neg_integer(),
          average_pipelines_per_node: float(),
          pipeline_distribution: %{atom() => non_neg_integer()}
        }
  @type t :: %__MODULE__{
          node_count: non_neg_integer(),
          nodes: [Epoxi.Node.t()],
          ip_pools: %{pool_name() => %{atom() => [String.t()]}}
        }

  def init(opts \\ []) do
    opts
    |> new()
    |> get_current_state()
  end

  def new(opts \\ []) do
    struct(Epoxi.Cluster, opts)
  end

  @spec get_current_state(cluster :: t()) :: t()
  def get_current_state(%Cluster{} = cluster \\ %Cluster{}) do
    nodes =
      connected_nodes()
      |> Enum.map(&Epoxi.Node.state/1)

    cluster =
      Enum.reduce(nodes, cluster, fn node, cluster ->
        add_node_to_ip_pool(cluster, node)
      end)

    %{cluster | nodes: nodes, node_count: length(nodes)}
  end

  @spec add_node(cluster :: t(), node :: Epoxi.Node.t()) :: t()
  def add_node(%Cluster{nodes: nodes} = cluster, %Epoxi.Node{} = node) do
    node_with_pool = ensure_ip_pool(node)
    updated_nodes = [node_with_pool | nodes]

    %{cluster | nodes: updated_nodes}
    |> add_node_to_ip_pool(node_with_pool)
  end

  @spec remove_node(cluster :: t(), node_to_remove :: Epoxi.Node.t()) :: t()
  def remove_node(%Cluster{nodes: nodes} = cluster, node_to_remove) do
    new_nodes = Enum.reject(nodes, fn node -> node.name == node_to_remove.name end)

    %{cluster | nodes: new_nodes, node_count: length(new_nodes)}
    |> remove_node_from_ip_pool(node_to_remove.name)
  end

  @spec add_node_to_ip_pool(cluster :: t(), node :: Epoxi.Node.t()) :: t()
  def add_node_to_ip_pool(
        %Cluster{ip_pools: ip_pools} = cluster,
        %Epoxi.Node{ip_pool: ip_pool, name: node_name, ip_addresses: ips} = _node
      ) do
    new_ip_pools =
      ip_pools
      |> Map.put_new(ip_pool, %{})
      |> put_in([ip_pool, node_name], ips || [])

    %{cluster | ip_pools: new_ip_pools}
  end

  @spec remove_node_from_ip_pool(cluster :: t(), node_to_remove :: node()) :: t()
  def remove_node_from_ip_pool(%Cluster{ip_pools: ip_pools} = cluster, node_to_remove) do
    new_ip_pools =
      Map.new(ip_pools, fn {pool_name, pool_nodes} ->
        {pool_name, Map.delete(pool_nodes, node_to_remove)}
      end)

    %{cluster | ip_pools: new_ip_pools}
  end

  @spec find_node(node_name :: node()) ::
          {:ok, Epoxi.Node.t()}
          | {:error, :not_found}
  def find_node(node_name) do
    connected_nodes()
    |> Enum.find({:error, :not_found}, fn cluster_node ->
      cluster_node.name == node_name
    end)
  end

  @spec find_node_in_cluster(cluster :: t(), node_name :: node()) ::
          {:ok, Epoxi.Node.t()} | {:error, :not_found}
  def find_node_in_cluster(%Cluster{nodes: nodes}, node_name) do
    case Enum.find(nodes, fn node -> node.name == node_name end) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  @spec find_ip_owner(cluster :: t(), ip_address :: String.t()) ::
          {:ok, Epoxi.Node.t()} | {:error, :not_found}
  def find_ip_owner(%Cluster{nodes: nodes}, ip_address) do
    case Enum.find(nodes, fn node -> ip_address in node.ip_addresses end) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  @spec find_ip_pool(cluster :: t(), atom()) :: %{atom() => [String.t()]}
  def find_ip_pool(%Cluster{ip_pools: ip_pools}, pool_name) do
    Map.get(ip_pools, pool_name, %{})
  end

  @spec get_all_ips(cluster :: t()) :: [ip_address()]
  def get_all_ips(%Cluster{nodes: nodes}) do
    nodes
    |> Enum.flat_map(& &1.ip_addresses)
    |> Enum.uniq()
  end

  @spec get_pool_ips(cluster :: t(), atom()) :: [String.t()]
  def get_pool_ips(%Cluster{} = cluster, pool_name) do
    cluster
    |> find_ip_pool(pool_name)
    |> Map.values()
    |> List.flatten()
  end

  @spec find_nodes_in_pool(cluster :: t(), atom()) :: [Epoxi.Node.t()]
  def find_nodes_in_pool(%Cluster{nodes: nodes} = cluster, pool_name) do
    pool_node_names =
      cluster
      |> find_ip_pool(pool_name)
      |> Map.keys()
      |> MapSet.new()

    Enum.filter(nodes, fn node -> node.name in pool_node_names end)
  end

  @spec select_node(cluster :: t(), strategy_fn :: fun()) :: [Epoxi.Node.t()]
  def select_node(%Cluster{nodes: nodes}, strategy_fn \\ fn nodes -> nodes end) do
    strategy_fn.(nodes)
  end

  @spec node_count(cluster :: t()) :: non_neg_integer()
  def node_count(%Cluster{nodes: nodes}), do: length(nodes)

  @doc """
  Finds all pipelines running across the cluster.

  Returns a map where keys are node names and values are lists of pipeline_info.
  """
  @spec find_all_pipelines(cluster :: t()) :: %{atom() => [Epoxi.Node.pipeline_info()]}
  def find_all_pipelines(%Cluster{nodes: nodes}) do
    nodes
    |> Enum.map(fn node ->
      pipelines = Epoxi.Node.get_pipelines(node)
      {node.name, pipelines}
    end)
    |> Map.new()
  end

  @doc """
  Finds all pipelines running across the cluster (using current cluster state).
  """
  @spec find_all_pipelines() :: %{atom() => [Epoxi.Node.pipeline_info()]}
  def find_all_pipelines do
    init()
    |> find_all_pipelines()
  end

  @doc """
  Finds pipelines by routing key across the cluster.

  Returns a map where keys are node names and values are lists of matching pipelines.
  """
  @spec find_pipelines_by_routing_key(cluster :: t(), String.t()) :: %{
          atom() => [Epoxi.Node.pipeline_info()]
        }
  def find_pipelines_by_routing_key(%Cluster{nodes: nodes}, routing_key) do
    nodes
    |> Enum.map(fn node ->
      pipelines = Epoxi.Node.find_pipelines_by_routing_key(node, routing_key)
      {node.name, pipelines}
    end)
    |> Enum.reject(fn {_node_name, pipelines} -> Enum.empty?(pipelines) end)
    |> Map.new()
  end

  @doc """
  Finds pipelines by routing key across the cluster (using current cluster state).
  """
  @spec find_pipelines_by_routing_key(String.t()) :: %{atom() => [Epoxi.Node.pipeline_info()]}
  def find_pipelines_by_routing_key(routing_key) do
    init()
    |> find_pipelines_by_routing_key(routing_key)
  end

  @doc """
  Finds a node that can handle a specific routing key.

  Returns the first node found that has a pipeline for the routing key.
  """
  @spec find_node_for_routing_key(cluster :: t(), String.t()) ::
          {:ok, Epoxi.Node.t()} | {:error, :not_found}
  def find_node_for_routing_key(%Cluster{nodes: nodes}, routing_key) do
    case Enum.find(nodes, fn node ->
           pipelines = Epoxi.Node.find_pipelines_by_routing_key(node, routing_key)
           not Enum.empty?(pipelines)
         end) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  @doc """
  Finds a node that can handle a specific routing key (using current cluster state).
  """
  @spec find_node_for_routing_key(String.t()) :: {:ok, Epoxi.Node.t()} | {:error, :not_found}
  def find_node_for_routing_key(routing_key) do
    init()
    |> find_node_for_routing_key(routing_key)
  end

  @doc """
  Gets pipeline statistics across the cluster.

  Returns statistics about pipeline distribution and load.
  """
  @spec get_pipeline_stats(cluster :: t()) :: pipeline_stats()
  def get_pipeline_stats(%Cluster{} = cluster) do
    pipeline_map = find_all_pipelines(cluster)

    total_pipelines =
      pipeline_map
      |> Map.values()
      |> List.flatten()
      |> length()

    nodes_with_pipelines =
      pipeline_map
      |> Enum.count(fn {_node, pipelines} -> not Enum.empty?(pipelines) end)

    node_count = node_count(cluster)

    average_pipelines_per_node =
      if node_count > 0, do: total_pipelines / node_count, else: 0.0

    pipeline_distribution =
      pipeline_map
      |> Enum.map(fn {node_name, pipelines} -> {node_name, length(pipelines)} end)
      |> Map.new()

    %{
      total_pipelines: total_pipelines,
      nodes_with_pipelines: nodes_with_pipelines,
      average_pipelines_per_node: average_pipelines_per_node,
      pipeline_distribution: pipeline_distribution
    }
  end

  @doc """
  Gets pipeline statistics across the cluster (using current cluster state).
  """
  @spec get_pipeline_stats() :: pipeline_stats()
  def get_pipeline_stats do
    init()
    |> get_pipeline_stats()
  end

  defp ensure_ip_pool(%Epoxi.Node{ip_pool: nil} = node) do
    %{node | ip_pool: :default}
  end

  defp ensure_ip_pool(%Epoxi.Node{} = node), do: node

  defp connected_nodes() do
    [Node.self() | Node.list()]
    |> Enum.map(&Epoxi.Node.from_node/1)
  end
end
