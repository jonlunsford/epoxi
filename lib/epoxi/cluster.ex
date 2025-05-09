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

  defstruct node_count: 0, nodes: []

  @type t :: %__MODULE__{
          node_count: non_neg_integer(),
          nodes: [Epoxi.Node.t()]
        }

  @doc """
  Creates a new Epoxi.Cluster struct with the given attributes.

  ## Parameters
    * `attrs` - A keyword list of attributes to initialize the cluster with.

  ## Examples
      iex> nodes = [%Epoxi.Node{name: :node1}, %Epoxi.Node{name: :node2}]
      iex> Epoxi.Cluster.new(nodes: nodes, node_count: 2)
      %Epoxi.Cluster{nodes: [%Epoxi.Node{name: :node1}, %Epoxi.Node{name: :node2}], node_count: 2}
  """
  def new(attrs \\ []) do
    struct(Epoxi.Cluster, attrs)
  end

  @doc """
  Updates and returns the current state of the cluster including all connected nodes.

  This function collects state information from all nodes in the cluster, including
  the local node, and updates the cluster struct with the latest information.

  ## Parameters
    * `cluster` - The Epoxi.Cluster struct to update

  ## Returns
    * Updated Epoxi.Cluster struct containing current node states

  ## Examples
      iex> cluster = Epoxi.Cluster.new()
      iex> updated_cluster = Epoxi.Cluster.state(cluster)
      iex> updated_cluster.node_count > 0
      true
  """
  @spec state(cluster :: t()) :: t()
  def state(%Epoxi.Cluster{} = cluster) do
    nodes =
      connected_nodes()
      |> Enum.map(&Epoxi.Node.from_node/1)
      |> Enum.map(&Epoxi.Node.state/1)

    %{cluster | nodes: nodes, node_count: length(nodes)}
  end

  @doc """
  Finds a specific node within the cluster by its node name.

  ## Parameters
    * `cluster` - The Epoxi.Cluster struct containing nodes to search
    * `node` - The name of the node to find (as an Erlang node name)

  ## Returns
    * `{:ok, node}` - The found Epoxi.Node struct
    * `{:error, :not_found}` - If the node is not found in the cluster

  ## Examples
      iex> cluster = Epoxi.Cluster.new(nodes: [%Epoxi.Node{name: :node1}])
      iex> Epoxi.Cluster.find_node(cluster, :node1)
      {:ok, %Epoxi.Node{name: :node1}}

      iex> cluster = Epoxi.Cluster.new(nodes: [%Epoxi.Node{name: :node1}])
      iex> Epoxi.Cluster.find_node(cluster, :nonexistent_node)
      {:error, :not_found}
  """
  @spec find_node(cluster :: t(), node :: node()) ::
          {:ok, Epoxi.Node.t()}
          | {:error, :not_found}
  def find_node(%Epoxi.Cluster{nodes: nodes}, node) do
    nodes
    |> Enum.find({:error, :not_found}, fn cluster_node -> cluster_node.name == node end)
  end

  defp connected_nodes() do
    [Node.self() | Node.list()]
  end
end
