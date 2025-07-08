defmodule Epoxi.PipelineManager do
  @moduledoc """
  Business logic for pipeline coordination and management in the Epoxi cluster.

  This module provides pure functions for pipeline registration, discovery,
  and coordination across cluster nodes without side effects. It operates on
  cluster state to make pipeline management decisions.
  """

  alias Epoxi.{Cluster, Node}

  @type pipeline_info :: Node.pipeline_info()
  @type routing_key :: String.t()
  @type selection_strategy :: :least_pipelines | :least_loaded | :random | :round_robin

  @doc """
  Registers a pipeline with a specific node in the cluster.
  """
  @spec register_pipeline(Cluster.t(), atom(), pipeline_info()) :: Cluster.t()
  def register_pipeline(%Cluster{nodes: nodes} = cluster, node_name, pipeline_info) do
    updated_nodes =
      Enum.map(nodes, fn node ->
        if node.name == node_name do
          updated_pipelines = [pipeline_info | node.pipelines]
          %{node | pipelines: updated_pipelines}
        else
          node
        end
      end)

    %{cluster | nodes: updated_nodes}
  end

  @doc """
  Unregisters a pipeline from a specific node in the cluster.
  """
  @spec unregister_pipeline(Cluster.t(), atom(), atom()) :: Cluster.t()
  def unregister_pipeline(%Cluster{nodes: nodes} = cluster, node_name, pipeline_name) do
    updated_nodes =
      Enum.map(nodes, fn node ->
        if node.name == node_name do
          updated_pipelines = Enum.reject(node.pipelines, &(&1.name == pipeline_name))
          %{node | pipelines: updated_pipelines}
        else
          node
        end
      end)

    %{cluster | nodes: updated_nodes}
  end

  @doc """
  Finds all pipelines running across the cluster.
  """
  @spec find_all_pipelines(Cluster.t()) :: %{atom() => [pipeline_info()]}
  def find_all_pipelines(%Cluster{nodes: nodes}) do
    nodes
    |> Enum.map(fn node -> {node.name, node.pipelines} end)
    |> Map.new()
  end

  @doc """
  Finds pipelines by routing key across the cluster.
  """
  @spec find_pipelines_by_routing_key(Cluster.t(), routing_key()) :: %{atom() => [pipeline_info()]}
  def find_pipelines_by_routing_key(%Cluster{nodes: nodes}, routing_key) do
    nodes
    |> Enum.map(fn node ->
      matching_pipelines = Enum.filter(node.pipelines, &(&1.routing_key == routing_key))
      {node.name, matching_pipelines}
    end)
    |> Enum.reject(fn {_node_name, pipelines} -> Enum.empty?(pipelines) end)
    |> Map.new()
  end

  @doc """
  Finds a specific pipeline by name across the cluster.
  """
  @spec find_pipeline_by_name(Cluster.t(), atom()) :: {:ok, {atom(), pipeline_info()}} | {:error, :not_found}
  def find_pipeline_by_name(%Cluster{nodes: nodes}, pipeline_name) do
    result =
      nodes
      |> Enum.find_value(fn node ->
        case Enum.find(node.pipelines, &(&1.name == pipeline_name)) do
          nil -> nil
          pipeline -> {node.name, pipeline}
        end
      end)

    case result do
      nil -> {:error, :not_found}
      {node_name, pipeline} -> {:ok, {node_name, pipeline}}
    end
  end

  @doc """
  Gets all pipelines running on a specific node.
  """
  @spec get_node_pipelines(Cluster.t(), atom()) :: [pipeline_info()]
  def get_node_pipelines(%Cluster{} = cluster, node_name) do
    case Cluster.find_node_in_cluster(cluster, node_name) do
      {:ok, node} -> node.pipelines
      {:error, :not_found} -> []
    end
  end

  @doc """
  Finds a node that can handle a specific routing key.
  """
  @spec find_node_for_routing_key(Cluster.t(), routing_key()) :: {:ok, Node.t()} | {:error, :not_found}
  def find_node_for_routing_key(%Cluster{nodes: nodes}, routing_key) do
    case Enum.find(nodes, fn node ->
           Enum.any?(node.pipelines, &(&1.routing_key == routing_key))
         end) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  @doc """
  Selects optimal node for starting a new pipeline based on strategy.
  """
  @spec select_optimal_node_for_pipeline(Cluster.t(), atom(), selection_strategy()) :: {:ok, Node.t()} | {:error, :no_nodes_available}
  def select_optimal_node_for_pipeline(%Cluster{} = cluster, ip_pool, strategy \\ :least_pipelines) do
    eligible_nodes = Cluster.find_nodes_in_pool(cluster, ip_pool)

    case eligible_nodes do
      [] ->
        {:error, :no_nodes_available}

      nodes ->
        optimal_node = 
          case strategy do
            :least_pipelines -> select_node_with_least_pipelines(nodes)
            :least_loaded -> select_node_with_least_load(nodes)
            :random -> Enum.random(nodes)
            :round_robin -> List.first(nodes)
          end

        {:ok, optimal_node}
    end
  end

  @doc """
  Gets comprehensive pipeline statistics for the cluster.
  """
  @spec get_pipeline_stats(Cluster.t()) :: %{
          total_pipelines: non_neg_integer(),
          nodes_with_pipelines: non_neg_integer(),
          average_pipelines_per_node: float(),
          pipeline_distribution: %{atom() => non_neg_integer()},
          routing_key_distribution: %{routing_key() => non_neg_integer()}
        }
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

    node_count = Cluster.node_count(cluster)

    average_pipelines_per_node =
      if node_count > 0, do: total_pipelines / node_count, else: 0.0

    pipeline_distribution =
      pipeline_map
      |> Enum.map(fn {node_name, pipelines} -> {node_name, length(pipelines)} end)
      |> Map.new()

    routing_key_distribution = calculate_routing_key_distribution(pipeline_map)

    %{
      total_pipelines: total_pipelines,
      nodes_with_pipelines: nodes_with_pipelines,
      average_pipelines_per_node: average_pipelines_per_node,
      pipeline_distribution: pipeline_distribution,
      routing_key_distribution: routing_key_distribution
    }
  end

  @doc """
  Checks if a pipeline exists for a specific routing key.
  """
  @spec pipeline_exists_for_routing_key?(Cluster.t(), routing_key()) :: boolean()
  def pipeline_exists_for_routing_key?(%Cluster{} = cluster, routing_key) do
    case find_node_for_routing_key(cluster, routing_key) do
      {:ok, _node} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Gets load balancing recommendations for pipeline distribution.
  """
  @spec get_load_balancing_recommendations(Cluster.t(), atom()) :: %{
          overloaded_nodes: [atom()],
          underloaded_nodes: [atom()],
          recommended_moves: [%{from: atom(), to: atom(), pipeline: atom()}]
        }
  def get_load_balancing_recommendations(%Cluster{} = cluster, ip_pool) do
    pool_nodes = Cluster.find_nodes_in_pool(cluster, ip_pool)
    
    if length(pool_nodes) < 2 do
      %{overloaded_nodes: [], underloaded_nodes: [], recommended_moves: []}
    else
      load_analysis = analyze_node_loads(pool_nodes)
      moves = calculate_recommended_moves(load_analysis)
      
      %{
        overloaded_nodes: Map.get(load_analysis, :overloaded, []),
        underloaded_nodes: Map.get(load_analysis, :underloaded, []),
        recommended_moves: moves
      }
    end
  end

  @doc """
  Validates pipeline configuration and placement.
  """
  @spec validate_pipeline_placement(Cluster.t(), atom(), pipeline_info()) :: 
          {:ok, :valid} | {:error, :node_not_found | :routing_key_conflict | :insufficient_resources}
  def validate_pipeline_placement(%Cluster{} = cluster, node_name, pipeline_info) do
    with {:ok, node} <- Cluster.find_node_in_cluster(cluster, node_name),
         :ok <- check_routing_key_conflict(node, pipeline_info),
         :ok <- check_node_resources(node, pipeline_info) do
      {:ok, :valid}
    else
      {:error, :not_found} -> {:error, :node_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp select_node_with_least_pipelines(nodes) do
    Enum.min_by(nodes, fn node -> length(node.pipelines) end)
  end

  defp select_node_with_least_load(nodes) do
    Enum.min_by(nodes, &calculate_node_load/1)
  end

  defp calculate_node_load(%Node{pipelines: pipelines}) do
    # Simple load calculation - could be enhanced with actual metrics
    length(pipelines) * 1.0
  end

  defp calculate_routing_key_distribution(pipeline_map) do
    pipeline_map
    |> Map.values()
    |> List.flatten()
    |> Enum.group_by(& &1.routing_key)
    |> Enum.map(fn {routing_key, pipelines} -> {routing_key, length(pipelines)} end)
    |> Map.new()
  end

  defp analyze_node_loads(nodes) do
    loads = Enum.map(nodes, fn node -> {node.name, calculate_node_load(node)} end)
    avg_load = loads |> Enum.map(&elem(&1, 1)) |> Enum.sum() |> Kernel./(length(loads))
    
    overloaded = 
      loads
      |> Enum.filter(fn {_node, load} -> load > avg_load * 1.5 end)
      |> Enum.map(&elem(&1, 0))
    
    underloaded = 
      loads
      |> Enum.filter(fn {_node, load} -> load < avg_load * 0.5 end)
      |> Enum.map(&elem(&1, 0))
    
    %{
      overloaded: overloaded,
      underloaded: underloaded,
      average_load: avg_load
    }
  end

  defp calculate_recommended_moves(%{overloaded: [], underloaded: _}), do: []
  defp calculate_recommended_moves(%{overloaded: _, underloaded: []}), do: []
  
  defp calculate_recommended_moves(%{overloaded: [over_node | _], underloaded: [under_node | _]}) do
    # Simple recommendation - move one pipeline from overloaded to underloaded
    [%{from: over_node, to: under_node, pipeline: :any}]
  end

  defp check_routing_key_conflict(%Node{pipelines: pipelines}, %{routing_key: routing_key}) do
    case Enum.find(pipelines, &(&1.routing_key == routing_key)) do
      nil -> :ok
      _existing -> {:error, :routing_key_conflict}
    end
  end

  defp check_node_resources(%Node{pipelines: pipelines}, _pipeline_info) do
    # Simple resource check - could be enhanced with actual capacity limits
    if length(pipelines) < 100 do
      :ok
    else
      {:error, :insufficient_resources}
    end
  end
end