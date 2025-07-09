defmodule Epoxi.NodeManager do
  @moduledoc """
  Business logic for managing nodes in the Epoxi cluster.

  This module provides pure functions for node registration, metadata management,
  and node selection strategies. It operates on cluster state and returns
  updated state or results without side effects.
  """

  alias Epoxi.{Cluster, Node}

  @type node_metadata :: %{
          optional(:health_score) => float(),
          optional(:load_metrics) => %{cpu: float(), memory: float()},
          optional(:capabilities) => [atom()],
          optional(:last_health_check) => DateTime.t()
        }

  @type node_selection_strategy :: :round_robin | :least_loaded | :random | :health_based

  @doc """
  Registers a node with the cluster.
  """
  @spec register_node(Cluster.t(), Node.t()) :: Cluster.t()
  def register_node(%Cluster{} = cluster, %Node{} = node) do
    Cluster.add_node(cluster, node)
  end

  @doc """
  Unregisters a node from the cluster.
  """
  @spec unregister_node(Cluster.t(), Node.t()) :: Cluster.t()
  def unregister_node(%Cluster{} = cluster, %Node{} = node) do
    Cluster.remove_node(cluster, node)
  end

  @doc """
  Gets node information from the cluster.
  """
  @spec get_node(Cluster.t(), atom()) :: {:ok, Node.t()} | {:error, :not_found}
  def get_node(%Cluster{} = cluster, node_name) do
    Cluster.find_node_in_cluster(cluster, node_name)
  end

  @doc """
  Lists all nodes in the cluster.
  """
  @spec list_nodes(Cluster.t()) :: [Node.t()]
  def list_nodes(%Cluster{nodes: nodes}) do
    nodes
  end

  @doc """
  Lists all nodes in a specific IP pool.
  """
  @spec list_nodes_in_pool(Cluster.t(), atom()) :: [Node.t()]
  def list_nodes_in_pool(%Cluster{} = cluster, pool_name) do
    Cluster.find_nodes_in_pool(cluster, pool_name)
  end


  @doc """
  Selects optimal nodes from the cluster based on strategy and criteria.
  """
  @spec select_optimal_nodes(Cluster.t(), node_selection_strategy(), map()) :: [Node.t()]
  def select_optimal_nodes(%Cluster{} = cluster, strategy, criteria \\ %{}) do
    nodes = get_eligible_nodes(cluster, criteria)

    case strategy do
      :round_robin -> nodes
      :least_loaded -> sort_by_load(nodes)
      :random -> Enum.shuffle(nodes)
      :health_based -> sort_by_health(nodes)
    end
  end

  @doc """
  Selects a single optimal node from the cluster.
  """
  @spec select_optimal_node(Cluster.t(), node_selection_strategy(), map()) ::
          {:ok, Node.t()} | {:error, :no_nodes_available}
  def select_optimal_node(%Cluster{} = cluster, strategy, criteria \\ %{}) do
    case select_optimal_nodes(cluster, strategy, criteria) do
      [] -> {:error, :no_nodes_available}
      [node | _] -> {:ok, node}
    end
  end

  @doc """
  Calculates node load based on pipelines.
  """
  @spec calculate_node_load(Node.t()) :: float()
  def calculate_node_load(%Node{pipelines: pipelines}) do
    length(pipelines) * 1.0
  end

  @doc """
  Calculates node health score based on status.
  """
  @spec calculate_node_health(Node.t()) :: float()
  def calculate_node_health(%Node{status: status}) do
    case status do
      :up -> 1.0
      :down -> 0.0
      :unknown -> 0.5
    end
  end

  @doc """
  Gets the total number of nodes in the cluster.
  """
  @spec node_count(Cluster.t()) :: non_neg_integer()
  def node_count(%Cluster{} = cluster) do
    Cluster.node_count(cluster)
  end

  @doc """
  Checks if a node is healthy and available.
  """
  @spec node_healthy?(Node.t()) :: boolean()
  def node_healthy?(%Node{status: :up} = node) do
    health_score = calculate_node_health(node)
    health_score >= 0.5
  end

  def node_healthy?(_node), do: false

  # Private helper functions

  defp get_eligible_nodes(%Cluster{} = cluster, criteria) do
    cluster
    |> list_nodes()
    |> filter_by_criteria(criteria)
  end

  defp filter_by_criteria(nodes, criteria) do
    nodes
    |> filter_by_pool(Map.get(criteria, :pool))
    |> filter_by_health(Map.get(criteria, :require_healthy, true))
    |> filter_by_capabilities(Map.get(criteria, :capabilities, []))
  end

  defp filter_by_pool(nodes, nil), do: nodes

  defp filter_by_pool(nodes, pool_name) do
    Enum.filter(nodes, fn node -> node.ip_pool == pool_name end)
  end

  defp filter_by_health(nodes, false), do: nodes

  defp filter_by_health(nodes, true) do
    Enum.filter(nodes, &node_healthy?/1)
  end

  defp filter_by_capabilities(nodes, []), do: nodes

  defp filter_by_capabilities(nodes, _required_capabilities) do
    # Capabilities filtering not implemented without metadata
    nodes
  end

  defp sort_by_load(nodes) do
    Enum.sort_by(nodes, &calculate_node_load/1)
  end

  defp sort_by_health(nodes) do
    Enum.sort_by(nodes, &calculate_node_health/1, :desc)
  end

end