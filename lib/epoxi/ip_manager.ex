defmodule Epoxi.IpManager do
  @moduledoc """
  Business logic for IP allocation and pool management in the Epoxi cluster.

  This module provides pure functions for IP allocation strategies, pool management,
  and IP weighting without side effects. It operates on cluster state and IP weights
  to make allocation decisions.
  """

  alias Epoxi.{Cluster, Node}

  @type ip_address :: String.t()
  @type pool_name :: atom()
  @type ip_weight :: non_neg_integer()
  @type ip_weights :: %{ip_address() => ip_weight()}
  @type allocation_strategy :: :round_robin | :weighted | :least_used | :random

  @doc """
  Allocates IP addresses to emails using the specified strategy.
  """
  @spec allocate_ips(
          [Epoxi.Email.t()],
          Cluster.t(),
          ip_weights(),
          pool_name(),
          allocation_strategy()
        ) ::
          [Epoxi.Email.t()]
  def allocate_ips(emails, cluster, ip_weights, pool_name, strategy \\ :weighted) do
    pool_ips = get_pool_ips(cluster, pool_name)

    case pool_ips do
      [] ->
        emails

      _ ->
        allocated_ips = generate_ip_allocation(pool_ips, ip_weights, strategy, length(emails))
        assign_ips_to_emails(emails, allocated_ips, pool_name)
    end
  end

  @doc """
  Gets all IP addresses available in a specific pool.
  """
  @spec get_pool_ips(Cluster.t(), pool_name()) :: [ip_address()]
  def get_pool_ips(%Cluster{} = cluster, pool_name) do
    Cluster.get_pool_ips(cluster, pool_name)
  end

  @doc """
  Gets all IP addresses for a specific node.
  """
  @spec get_node_ips(Cluster.t(), atom()) :: [ip_address()]
  def get_node_ips(%Cluster{} = cluster, node_name) do
    case Cluster.find_node_in_cluster(cluster, node_name) do
      {:ok, node} -> node.ip_addresses || []
      {:error, :not_found} -> []
    end
  end

  @doc """
  Finds which node owns a specific IP address.
  """
  @spec find_ip_owner(Cluster.t(), ip_address()) :: {:ok, atom()} | {:error, :not_found}
  def find_ip_owner(%Cluster{} = cluster, ip_address) do
    case Cluster.find_ip_owner(cluster, ip_address) do
      {:ok, node} -> {:ok, node.name}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Gets all IP addresses across the entire cluster.
  """
  @spec get_all_cluster_ips(Cluster.t()) :: [{ip_address(), atom()}]
  def get_all_cluster_ips(%Cluster{} = cluster) do
    cluster.nodes
    |> Enum.flat_map(fn node ->
      Enum.map(node.ip_addresses || [], fn ip -> {ip, node.name} end)
    end)
  end

  @doc """
  Sets the weight for a specific IP address.
  """
  @spec set_ip_weight(ip_weights(), ip_address(), ip_weight()) :: ip_weights()
  def set_ip_weight(ip_weights, ip_address, weight) do
    Map.put(ip_weights, ip_address, weight)
  end

  @doc """
  Gets the weight for a specific IP address.
  Returns 1 (default weight) if no weight is set.
  """
  @spec get_ip_weight(ip_weights(), ip_address()) :: ip_weight()
  def get_ip_weight(ip_weights, ip_address) do
    Map.get(ip_weights, ip_address, 1)
  end

  @doc """
  Gets all IP weights for a specific pool.
  """
  @spec get_pool_ip_weights(Cluster.t(), ip_weights(), pool_name()) :: %{
          ip_address() => ip_weight()
        }
  def get_pool_ip_weights(%Cluster{} = cluster, ip_weights, pool_name) do
    pool_ips = get_pool_ips(cluster, pool_name)
    Map.take(ip_weights, pool_ips)
  end

  @doc """
  Validates that an IP address is available in the cluster.
  """
  @spec validate_ip_available?(Cluster.t(), ip_address()) :: boolean()
  def validate_ip_available?(%Cluster{} = cluster, ip_address) do
    case find_ip_owner(cluster, ip_address) do
      {:ok, _node} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Gets IP distribution statistics for a pool.
  """
  @spec get_pool_stats(Cluster.t(), pool_name()) :: %{
          total_ips: non_neg_integer(),
          nodes_with_ips: non_neg_integer(),
          ip_distribution: %{atom() => non_neg_integer()}
        }
  def get_pool_stats(%Cluster{} = cluster, pool_name) do
    pool_nodes = Cluster.find_nodes_in_pool(cluster, pool_name)

    ip_distribution =
      pool_nodes
      |> Enum.map(fn node -> {node.name, length(node.ip_addresses || [])} end)
      |> Map.new()

    total_ips = ip_distribution |> Map.values() |> Enum.sum()
    nodes_with_ips = ip_distribution |> Enum.count(fn {_node, count} -> count > 0 end)

    %{
      total_ips: total_ips,
      nodes_with_ips: nodes_with_ips,
      ip_distribution: ip_distribution
    }
  end

  @doc """
  Suggests optimal IP weights based on node capacity and health.
  """
  @spec suggest_ip_weights(Cluster.t(), pool_name()) :: ip_weights()
  def suggest_ip_weights(%Cluster{} = cluster, pool_name) do
    pool_nodes = Cluster.find_nodes_in_pool(cluster, pool_name)

    pool_nodes
    |> Enum.flat_map(fn node ->
      node_health = calculate_node_health_score(node)
      node_capacity = calculate_node_capacity(node)
      suggested_weight = round(node_health * node_capacity * 10)

      Enum.map(node.ip_addresses || [], fn ip -> {ip, suggested_weight} end)
    end)
    |> Map.new()
  end

  # Private helper functions

  defp generate_ip_allocation(pool_ips, ip_weights, strategy, count) do
    case strategy do
      :round_robin ->
        generate_round_robin_allocation(pool_ips, count)

      :weighted ->
        generate_weighted_allocation(pool_ips, ip_weights, count)

      :least_used ->
        generate_least_used_allocation(pool_ips, count)

      :random ->
        generate_random_allocation(pool_ips, count)
    end
  end

  defp generate_round_robin_allocation(pool_ips, count) do
    pool_ips
    |> Stream.cycle()
    |> Enum.take(count)
  end

  defp generate_weighted_allocation(pool_ips, ip_weights, count) do
    weighted_ips = build_weighted_ip_list(pool_ips, ip_weights)

    case weighted_ips do
      [] ->
        generate_round_robin_allocation(pool_ips, count)

      _ ->
        weighted_ips
        |> Stream.cycle()
        |> Enum.take(count)
    end
  end

  defp generate_least_used_allocation(pool_ips, count) do
    # Simple implementation - in practice, you'd track usage
    generate_round_robin_allocation(pool_ips, count)
  end

  defp generate_random_allocation(pool_ips, count) do
    for _ <- 1..count do
      Enum.random(pool_ips)
    end
  end

  defp build_weighted_ip_list(pool_ips, ip_weights) do
    pool_ips
    |> Enum.flat_map(fn ip ->
      weight = get_ip_weight(ip_weights, ip)
      List.duplicate(ip, weight)
    end)
    |> Enum.shuffle()
  end

  defp assign_ips_to_emails(emails, allocated_ips, pool_name) do
    emails
    |> Enum.zip(allocated_ips)
    |> Enum.map(fn {email, ip} ->
      delivery_config = %{ip: ip, ip_pool: Atom.to_string(pool_name)}
      %{email | delivery: delivery_config}
    end)
  end

  defp calculate_node_health_score(%Node{status: :up}), do: 1.0
  defp calculate_node_health_score(%Node{status: :down}), do: 0.0
  defp calculate_node_health_score(%Node{status: :unknown}), do: 0.5

  defp calculate_node_capacity(%Node{pipelines: pipelines}) do
    # Simple capacity calculation - more pipelines = less capacity
    base_capacity = 1.0
    pipeline_count = length(pipelines)
    max(0.1, base_capacity - pipeline_count * 0.1)
  end
end
