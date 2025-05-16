defmodule Epoxi.Cluster do
  @moduledoc """
  Provides functionality for managing and interacting with a cluster of Epoxi.Node instances.

  This module offers capabilities for:
  - Creating and managing cluster representations
  - Tracking connected nodes within the cluster
  - Retrieving aggregated state information from all nodes
  - Finding specific nodes within the cluster

  It serves as a central component for managing distributed node operations in the Epoxi system.
  """

  alias Epoxi.Cluster

  defstruct node_count: 0, nodes: [], pools: %{default: MapSet.new()}

  @type pool_name :: atom()
  @type t :: %__MODULE__{
          node_count: non_neg_integer(),
          nodes: [Epoxi.Node.t()],
          pools: %{pool_name() => MapSet.t(Epoxi.Node.t())}
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
        add_node_to_pool(cluster, node)
      end)

    %{cluster | node_count: length(nodes)}
  end

  @spec add_node_to_pool(cluster :: t(), node :: Epoxi.Node.t()) :: t()
  def add_node_to_pool(%Cluster{pools: pools} = cluster, %Epoxi.Node{ip_pool: ip_pool} = node) do
    {_old, new_value} =
      pools
      |> Map.put_new(ip_pool, MapSet.new())
      |> Map.get_and_update(ip_pool, fn map_set -> {map_set, MapSet.put(map_set, node)} end)

    %{cluster | pools: new_value}
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

  @spec find_pool(cluster :: t(), atom()) :: [Epoxi.Node.t()]
  def find_pool(%Cluster{pools: pools}, pool_name) do
    pools
    |> Map.get(pool_name)
    |> MapSet.to_list()
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
