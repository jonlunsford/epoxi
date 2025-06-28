defmodule Epoxi.IpPool do
  @moduledoc """
  Manages IP pool assignment for email delivery.
  
  Handles IP allocation, rate limiting, and distribution across available IPs
  based on provider policies and pool configurations.
  """

  alias Epoxi.{Email, ProviderPolicy, Parsing, IpRegistry}

  @doc """
  Assign IPs to emails based on the named IP pool and provider policies.
  This happens before messages enter the queue/pipeline.
  """
  @spec assign_ips([Email.t()], atom()) :: [Email.t()]
  def assign_ips(emails, pool_name) do
    # Group emails by domain for efficient processing
    emails_by_domain = Enum.group_by(emails, fn email ->
      Parsing.get_hostname(email.to)
    end)
    
    Enum.flat_map(emails_by_domain, fn {domain, domain_emails} ->
      assign_ips_for_domain(domain_emails, domain, pool_name)
    end)
  end

  @doc """
  Assign IPs for all emails going to a specific domain.
  """
  @spec assign_ips_for_domain([Email.t()], String.t(), atom()) :: [Email.t()]
  def assign_ips_for_domain(emails, domain, pool_name) do
    policy = ProviderPolicy.get_policy(domain)
    available_ips = get_pool_ips(pool_name, domain)
    
    emails
    |> distribute_across_ips(available_ips, policy)
    |> Enum.map(fn {email, ip} ->
      Email.assign_ip(email, ip, pool_name, policy)
    end)
  end

  @doc """
  Get available IPs from the named pool for a specific domain.
  Now uses cluster-wide IP discovery instead of hardcoded IPs.
  """
  @spec get_pool_ips(atom(), String.t()) :: [String.t()]
  def get_pool_ips(pool_name, _domain) do
    case IpRegistry.get_pool_ips(pool_name) do
      pool_ips when map_size(pool_ips) > 0 ->
        # Flatten all IPs from all nodes in the pool
        pool_ips
        |> Map.values()
        |> List.flatten()
        
      _empty_pool ->
        # Fallback to local node IPs if pool is empty or not found
        get_fallback_ips(pool_name)
    end
  end

  @doc """
  Distribute emails across available IPs using round-robin distribution.
  """
  @spec distribute_across_ips([Email.t()], [String.t()], map()) :: [{Email.t(), String.t()}]
  def distribute_across_ips(emails, available_ips, _policy) when available_ips == [] do
    # Fallback to localhost if no IPs available
    Enum.map(emails, fn email -> {email, "127.0.0.1"} end)
  end

  def distribute_across_ips(emails, available_ips, _policy) do
    # Simple round-robin distribution for now
    # In production, this would consider rate limits, current usage, etc.
    ip_cycle = Stream.cycle(available_ips)
    
    emails
    |> Enum.zip(ip_cycle)
    |> Enum.map(fn {email, ip} ->
      {email, ip}
    end)
  end

  @doc """
  Track IP usage for rate limiting purposes.
  This would be called from the pipeline when emails are actually sent.
  """
  @spec track_usage(String.t(), String.t(), non_neg_integer()) :: :ok
  def track_usage(ip, domain, message_count) do
    # TODO: Implement actual rate limiting tracking
    # This could use ETS tables, GenServer state, or external storage
    # For now, just log the usage
    require Logger
    Logger.debug("IP #{ip} sent #{message_count} messages to #{domain}")
    :ok
  end

  @doc """
  Check if an IP can handle additional messages based on rate limits.
  """
  @spec can_handle_messages?(String.t(), String.t(), non_neg_integer()) :: boolean()
  def can_handle_messages?(_ip, _domain, _message_count) do
    # TODO: Implement actual rate limit checking
    # This would check current usage against provider policies
    true
  end

  @doc """
  Get optimal IP allocation for a batch of messages to the same domain.
  This is used for batch processing optimization.
  """
  @spec allocate_batch(String.t(), map(), non_neg_integer()) :: [String.t()]
  def allocate_batch(domain, policy, message_count) do
    available_ips = get_pool_ips(:default, domain)
    max_per_ip = div(policy.max_messages_per_minute, 60) # Convert to per-second rate
    
    distribute_messages_across_ips(available_ips, message_count, max_per_ip)
  end

  @doc """
  Get IPs available for a specific pool from the cluster registry.
  Returns a map of node_name => [ip_addresses] for the pool.
  """
  @spec get_pool_node_ips(atom()) :: %{atom() => [String.t()]}
  def get_pool_node_ips(pool_name) do
    IpRegistry.get_pool_ips(pool_name)
  end

  @doc """
  Get all cluster IPs with their owning nodes.
  Useful for debugging and monitoring.
  """
  @spec get_all_cluster_ips() :: [{String.t(), atom()}]
  def get_all_cluster_ips() do
    IpRegistry.get_all_cluster_ips()
  end

  # Private helper functions

  defp get_fallback_ips(pool_name) do
    # Try to get local node IPs first
    case IpRegistry.get_node_ips(Node.self()) do
      [] ->
        # Ultimate fallback to hardcoded localhost IPs
        get_hardcoded_fallback_ips(pool_name)
        
      local_ips ->
        local_ips
    end
  end

  defp get_hardcoded_fallback_ips(pool_name) do
    # Last resort hardcoded IPs for development/testing
    case pool_name do
      :default -> ["127.0.0.1"]
      :high_volume -> ["127.0.0.1", "127.0.0.2"]
      :warmup -> ["127.0.0.1"]
      _ -> ["127.0.0.1"]
    end
  end

  defp distribute_messages_across_ips([], message_count, _max_per_ip) do
    # Fallback to localhost
    List.duplicate("127.0.0.1", message_count)
  end

  defp distribute_messages_across_ips(ips, message_count, _max_per_ip) do
    # Simple round-robin for now
    # TODO: Implement quota-aware distribution
    ips
    |> Stream.cycle()
    |> Enum.take(message_count)
  end
end