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

  @type pool_name :: atom()
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

  @spec add_node_to_ip_pool(cluster :: t(), node :: Epoxi.Node.t()) :: t()
  def add_node_to_ip_pool(%Cluster{ip_pools: ip_pools} = cluster, %Epoxi.Node{ip_pool: ip_pool, name: node_name, ip_addresses: ips} = _node) do
    new_ip_pools =
      ip_pools
      |> Map.put_new(ip_pool, %{})
      |> put_in([ip_pool, node_name], ips || [])

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

  @spec find_ip_pool(cluster :: t(), atom()) :: %{atom() => [String.t()]}
  def find_ip_pool(%Cluster{ip_pools: ip_pools}, pool_name) do
    Map.get(ip_pools, pool_name, %{})
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

  defp connected_nodes() do
    [Node.self() | Node.list()]
    |> Enum.map(&Epoxi.Node.from_node/1)
  end
end
