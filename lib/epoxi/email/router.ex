defmodule Epoxi.Email.Router do
  @moduledoc """
  Handles intelligent routing of email batches to appropriate pipelines in a distributed cluster.

  This module encapsulates the logic for:
  - Finding existing pipelines that can handle specific routing keys
  - Starting new pipelines when needed
  - Routing email batches to the optimal nodes/pipelines
  - Providing fallback routing when primary routing fails
  """

  require Logger

  alias Epoxi.{Cluster, Node}
  alias Epoxi.Email.Batch

  @type routing_result :: {:ok, routing_summary()} | {:error, String.t()}
  @type routing_summary :: %{
          total_emails: non_neg_integer(),
          total_batches: non_neg_integer(),
          successful_batches: non_neg_integer(),
          failed_batches: non_neg_integer(),
          new_pipelines_started: non_neg_integer()
        }

  @doc """
  Routes a list of emails to appropriate pipelines in the cluster.

  This is the main entry point for email routing. It will:
  1. Group emails into batches by routing key
  2. Find or create pipelines for each routing key
  3. Route batches to the appropriate nodes
  4. Return a summary of the routing operation

  ## Parameters
  - `emails`: List of emails to route
  - `ip_pool`: The IP pool to use for routing (atom)
  - `opts`: Optional routing configuration

  ## Options
  - `:batch_size` - Maximum emails per batch (default: 50)
  - `:auto_create_pipelines` - Whether to create pipelines if none exist (default: true)
  - `:fallback_routing` - Whether to use fallback routing on errors (default: true)

  ## Returns
  - `{:ok, routing_summary}` - Success with routing statistics
  - `{:error, reason}` - Failure with error description
  """
  @spec route_emails([Epoxi.Email.t()], atom(), keyword()) :: routing_result()
  def route_emails(emails, ip_pool, opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 50)

    with {:ok, batches} <- prepare_batches(emails, ip_pool, batch_size),
         {:ok, cluster} <- get_cluster_state(),
         {:ok, results} <- route_batches(batches, cluster, ip_pool) do
      summary = summarize_routing_results(batches, results)
      {:ok, summary}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Finds the optimal node for a specific routing key.

  Returns the node that currently has a pipeline handling the given routing key,
  or an error if no such pipeline exists.
  """
  @spec find_node_for_routing_key(String.t()) :: {:ok, Node.t()} | {:error, :not_found}
  def find_node_for_routing_key(routing_key) do
    Epoxi.NodeRegistry.find_node_for_routing_key(routing_key)
  end

  @doc """
  Gets statistics about pipeline distribution across the cluster.
  """
  @spec get_pipeline_stats() :: map()
  def get_pipeline_stats do
    Epoxi.NodeRegistry.get_pipeline_stats()
  end

  # Private implementation functions

  defp prepare_batches(emails, ip_pool, batch_size) do
    batches =
      emails
      |> Epoxi.NodeRegistry.allocate_ips(ip_pool)
      |> Batch.from_emails(size: batch_size)

    {:ok, batches}
  end

  defp get_cluster_state do
    cluster = Cluster.init()
    {:ok, cluster}
  end

  defp route_batches(batches, cluster, ip_pool) do
    results =
      batches
      |> Enum.map(fn batch ->
        route_single_batch(batch, cluster, ip_pool)
      end)

    {:ok, results}
  end

  defp route_single_batch(batch, cluster, ip_pool) do
    case create_pipeline_for_batch(batch, cluster, ip_pool) do
      {:ok, node} ->
        result = enqueue_batch_to_node(batch, node)
        %{result | pipeline_created: true}

      {:error, _reason} ->
        fallback_route_batch(batch, cluster, ip_pool)
    end
  end

  defp create_pipeline_for_batch(batch, cluster, ip_pool) do
    with {:ok, node} <- select_node_for_new_pipeline(cluster, ip_pool),
         {:ok, _pid} <- start_pipeline_on_node(node, batch) do
      {:ok, node}
    else
      error ->
        {:error, error}
    end
  end

  defp select_node_for_new_pipeline(_cluster, ip_pool) do
    case Epoxi.NodeRegistry.select_optimal_node_for_pipeline(ip_pool, :least_pipelines) do
      {:ok, node} -> {:ok, node}
      {:error, :no_nodes_available} -> {:error, "No nodes available in pool #{ip_pool}"}
    end
  end

  defp start_pipeline_on_node(node, batch) do
    opts = Epoxi.Queue.Pipeline.build_policy_opts(batch)
    Node.route_call(node, Epoxi, :start_pipeline, [opts])
  end

  defp enqueue_batch_to_node(batch, node) do
    inbox = String.to_atom("#{batch.routing_key}_inbox")

    case Node.route_cast(node, Epoxi.Queue, :enqueue_many, [inbox, batch.emails]) do
      :ok ->
        %{success: true, batch: batch, node: node.name, pipeline_created: false}

      {:ok, :message_sent_async} ->
        %{success: true, batch: batch, node: node.name, pipeline_created: false}

      {:error, reason} ->
        %{success: false, error: reason, batch: batch}
    end
  end

  defp fallback_route_batch(batch, cluster, ip_pool) do
    Logger.info("Using fallback routing for batch with routing key: #{batch.routing_key}")

    case Cluster.find_nodes_in_pool(cluster, ip_pool) do
      [] ->
        %{success: false, error: "No nodes available in pool #{ip_pool}", batch: batch}

      nodes ->
        node = Enum.random(nodes)
        result = enqueue_batch_to_node(batch, node)
        Map.put(result, :fallback_used, true)
    end
  end

  defp summarize_routing_results(batches, results) do
    total_emails = Enum.sum(Enum.map(batches, & &1.size))
    total_batches = length(batches)
    successful_batches = Enum.count(results, & &1.success)
    failed_batches = total_batches - successful_batches
    new_pipelines = Enum.count(results, &Map.get(&1, :pipeline_created, false))

    %{
      total_emails: total_emails,
      total_batches: total_batches,
      successful_batches: successful_batches,
      failed_batches: failed_batches,
      new_pipelines_started: new_pipelines
    }
  end
end
