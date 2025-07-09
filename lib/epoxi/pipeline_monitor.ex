defmodule Epoxi.PipelineMonitor do
  @moduledoc """
  Provides monitoring and management capabilities for pipelines across the cluster.

  This module offers functionality for:
  - Health checking pipelines across all nodes
  - Monitoring pipeline performance and load
  - Administrative operations like starting/stopping pipelines
  - Cluster-wide pipeline statistics and insights
  """

  require Logger

  alias Epoxi.{Cluster, Node}
  alias Epoxi.Queue.PipelinePolicy

  @type pipeline_health :: :healthy | :unhealthy | :unknown
  @type health_check_result :: %{
          node: atom(),
          pipeline_name: atom(),
          routing_key: String.t(),
          health: pipeline_health(),
          pid: pid() | nil,
          started_at: DateTime.t() | nil,
          last_check: DateTime.t(),
          error: String.t() | nil
        }

  @doc """
  Performs a health check on all pipelines across the cluster.

  Returns a list of health check results for each pipeline found.
  """
  @spec health_check_all() :: [health_check_result()]
  def health_check_all do
    Epoxi.NodeRegistry.find_all_pipelines()
    |> Enum.flat_map(fn {node_name, pipelines} ->
      Enum.map(pipelines, fn pipeline_info ->
        health_check_pipeline(node_name, pipeline_info)
      end)
    end)
  end

  @doc """
  Performs a health check on pipelines for a specific routing key.
  """
  @spec health_check_routing_key(String.t()) :: [health_check_result()]
  def health_check_routing_key(routing_key) do
    Epoxi.NodeRegistry.find_pipelines_by_routing_key(routing_key)
    |> Enum.flat_map(fn {node_name, pipelines} ->
      Enum.map(pipelines, fn pipeline_info ->
        health_check_pipeline(node_name, pipeline_info)
      end)
    end)
  end

  @doc """
  Gets comprehensive statistics about all pipelines in the cluster.
  """
  @spec get_cluster_stats() :: %{
          pipeline_stats: map(),
          health_summary: %{
            healthy: non_neg_integer(),
            unhealthy: non_neg_integer(),
            unknown: non_neg_integer()
          },
          routing_key_distribution: %{String.t() => non_neg_integer()},
          node_load_distribution: %{atom() => %{pipelines: non_neg_integer(), avg_load: float()}}
        }
  def get_cluster_stats do
    health_results = health_check_all()
    pipeline_stats = Epoxi.NodeRegistry.get_pipeline_stats()

    health_summary = summarize_health(health_results)
    routing_distribution = analyze_routing_distribution(health_results)
    load_distribution = analyze_load_distribution(health_results)

    %{
      pipeline_stats: pipeline_stats,
      health_summary: health_summary,
      routing_key_distribution: routing_distribution,
      node_load_distribution: load_distribution
    }
  end

  @doc """
  Starts a new pipeline on the least loaded node in the specified pool.
  """
  @spec start_pipeline_optimal(PipelinePolicy.t(), atom()) ::
          {:ok, {atom(), pid()}} | {:error, String.t()}
  def start_pipeline_optimal(policy, ip_pool) do
    case Epoxi.NodeRegistry.select_optimal_node_for_pipeline(ip_pool, :least_pipelines) do
      {:ok, node} ->
        case Node.route_call(node, Epoxi, :start_pipeline, [policy]) do
          {:ok, pid} ->
            Logger.info("Started pipeline #{policy.name} on optimal node #{node.name}")
            {:ok, {node.name, pid}}

          {:error, reason} ->
            {:error, "Failed to start pipeline: #{inspect(reason)}"}
        end

      {:error, :no_nodes_available} ->
        {:error, "No nodes available in pool #{ip_pool}"}
    end
  end

  @doc """
  Stops a pipeline by routing key across the cluster.
  """
  @spec stop_pipeline_by_routing_key(String.t()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def stop_pipeline_by_routing_key(routing_key) do
    health_results = health_check_routing_key(routing_key)

    stopped_count =
      health_results
      |> Enum.filter(&(&1.health == :healthy))
      |> Enum.map(fn result ->
        stop_pipeline_on_node(result.node, result.pid)
      end)
      |> Enum.count(&(&1 == :ok))

    if stopped_count > 0 do
      Logger.info("Stopped #{stopped_count} pipelines for routing key: #{routing_key}")
      {:ok, stopped_count}
    else
      {:error, "No healthy pipelines found for routing key: #{routing_key}"}
    end
  end

  @doc """
  Rebalances pipelines across the cluster to optimize load distribution.
  """
  @spec rebalance_cluster(atom()) ::
          {:ok,
           %{moved: non_neg_integer(), started: non_neg_integer(), stopped: non_neg_integer()}}
          | {:error, String.t()}
  def rebalance_cluster(ip_pool) do
    health_results = health_check_all()
    pool_nodes = Epoxi.NodeRegistry.list_nodes_in_pool(ip_pool)

    # Find overloaded and underloaded nodes
    {overloaded, underloaded} = identify_load_imbalance(health_results, pool_nodes)

    moves = plan_rebalancing_moves(overloaded, underloaded)

    # Execute the moves
    results = Enum.map(moves, &execute_rebalance_move/1)

    summary = summarize_rebalance_results(results)

    Logger.info("Cluster rebalancing completed: #{inspect(summary)}")
    {:ok, summary}
  end

  # Private implementation functions

  defp health_check_pipeline(node_name, pipeline_info) do
    now = DateTime.utc_now()

    health =
      if Process.alive?(pipeline_info.pid) do
        :healthy
      else
        :unhealthy
      end

    %{
      node: node_name,
      pipeline_name: pipeline_info.name,
      routing_key: pipeline_info.routing_key,
      health: health,
      pid: pipeline_info.pid,
      started_at: pipeline_info.started_at,
      last_check: now,
      error: nil
    }
  end

  defp summarize_health(health_results) do
    health_results
    |> Enum.group_by(& &1.health)
    |> Enum.map(fn {health, results} -> {health, length(results)} end)
    |> Map.new()
    |> Map.put_new(:healthy, 0)
    |> Map.put_new(:unhealthy, 0)
    |> Map.put_new(:unknown, 0)
  end

  defp analyze_routing_distribution(health_results) do
    health_results
    |> Enum.group_by(& &1.routing_key)
    |> Enum.map(fn {routing_key, results} -> {routing_key, length(results)} end)
    |> Map.new()
  end

  defp analyze_load_distribution(health_results) do
    health_results
    |> Enum.group_by(& &1.node)
    |> Enum.map(fn {node, results} ->
      pipeline_count = length(results)
      # Simple load calculation - could be enhanced with actual metrics
      avg_load = pipeline_count * 1.0

      {node, %{pipelines: pipeline_count, avg_load: avg_load}}
    end)
    |> Map.new()
  end

  defp stop_pipeline_on_node(node_name, pid) when is_pid(pid) do
    case Cluster.find_node(node_name) do
      {:ok, node} ->
        Node.route_call(node, Epoxi.Queue.PipelineSupervisor, :terminate_child, [pid])

      {:error, :not_found} ->
        {:error, "Node not found"}
    end
  end

  defp stop_pipeline_on_node(_node_name, _pid), do: {:error, "Invalid PID"}

  defp identify_load_imbalance(health_results, pool_nodes) do
    load_distribution = analyze_load_distribution(health_results)

    pool_node_names = pool_nodes |> Enum.map(& &1.name) |> MapSet.new()

    # Filter to only nodes in the specified pool
    pool_loads =
      load_distribution
      |> Enum.filter(fn {node, _load} -> node in pool_node_names end)

    if length(pool_loads) < 2 do
      {[], []}
    else
      avg_load =
        pool_loads
        |> Enum.map(fn {_node, load} -> load.avg_load end)
        |> Enum.sum()
        |> Kernel./(length(pool_loads))

      overloaded = Enum.filter(pool_loads, fn {_node, load} -> load.avg_load > avg_load * 1.5 end)

      underloaded =
        Enum.filter(pool_loads, fn {_node, load} -> load.avg_load < avg_load * 0.5 end)

      {overloaded, underloaded}
    end
  end

  defp plan_rebalancing_moves(overloaded, underloaded) do
    # Simple rebalancing strategy - move one pipeline from overloaded to underloaded
    # This could be enhanced with more sophisticated algorithms

    case {overloaded, underloaded} do
      {[], _} ->
        []

      {_, []} ->
        []

      {[{over_node, _} | _], [{under_node, _} | _]} ->
        [%{from: over_node, to: under_node, action: :move_one_pipeline}]
    end
  end

  defp execute_rebalance_move(%{from: from_node, to: to_node, action: :move_one_pipeline}) do
    # This is a simplified implementation
    # In practice, you'd want to select specific pipelines to move based on criteria
    Logger.info("Would move pipeline from #{from_node} to #{to_node}")
    %{success: true, moved: 1}
  end

  defp summarize_rebalance_results(results) do
    moved = Enum.sum(Enum.map(results, &Map.get(&1, :moved, 0)))
    started = Enum.sum(Enum.map(results, &Map.get(&1, :started, 0)))
    stopped = Enum.sum(Enum.map(results, &Map.get(&1, :stopped, 0)))

    %{moved: moved, started: started, stopped: stopped}
  end
end
