defmodule Epoxi.MessageRouter do
  @moduledoc """
  Routes messages to appropriate nodes based on assigned IP ownership.
  
  This module handles the cluster coordination layer, ensuring messages
  with assigned IPs are routed to the nodes that own those IPs for delivery.
  
  Key responsibilities:
  - Route messages to IP-owning nodes
  - Handle local vs remote message routing
  - Provide fallback routing strategies
  - Maintain lightweight message forwarding
  """
  
  require Logger
  
  alias Epoxi.{Email, IpRegistry}
  
  @type routing_result :: :local | {:remote, node()} | {:error, term()}
  
  @doc """
  Route a single email to the appropriate node based on its assigned IP.
  Returns the routing decision without actually sending the message.
  """
  @spec route_email(Email.t()) :: routing_result()
  def route_email(%Email{assigned_ip: nil}) do
    Logger.warning("Email has no assigned IP, routing to local node")
    :local
  end
  
  def route_email(%Email{assigned_ip: ip}) do
    case IpRegistry.find_ip_owner(ip) do
      {:ok, node_name} ->
        if node_name == Node.self() do
          :local
        else
          {:remote, node_name}
        end
        
      {:error, :not_found} ->
        Logger.warning("IP #{ip} not found in cluster, routing to local")
        :local
    end
  end
  
  @doc """
  Route a batch of emails, grouping them by target node.
  Returns a map of routing_target => [emails]
  """
  @spec route_batch([Email.t()]) :: %{routing_result() => [Email.t()]}
  def route_batch(emails) when is_list(emails) do
    emails
    |> Enum.group_by(&route_email/1)
  end
  
  @doc """
  Send an email to a remote node for processing.
  Uses the Node module's routing capabilities.
  """
  @spec send_to_node(Email.t(), node()) :: :ok | {:error, term()}
  def send_to_node(%Email{} = email, target_node) when is_atom(target_node) do
    node = Epoxi.Node.from_node(target_node)
    
    try do
      Epoxi.Node.route_cast(node, Epoxi.MessageRouter, :receive_remote_email, [email])
      :ok
    rescue
      error ->
        Logger.error("Failed to route email to #{target_node}: #{inspect(error)}")
        {:error, {:routing_failed, error}}
    end
  end
  
  @doc """
  Send a batch of emails to a remote node.
  More efficient than sending individual emails.
  """
  @spec send_batch_to_node([Email.t()], node()) :: :ok | {:error, term()}
  def send_batch_to_node(emails, target_node) when is_list(emails) and is_atom(target_node) do
    node = Epoxi.Node.from_node(target_node)
    
    try do
      Epoxi.Node.route_cast(node, Epoxi.MessageRouter, :receive_remote_batch, [emails])
      :ok
    rescue
      error ->
        Logger.error("Failed to route batch of #{length(emails)} emails to #{target_node}: #{inspect(error)}")
        {:error, {:routing_failed, error}}
    end
  end
  
  @doc """
  Process emails by routing them to appropriate nodes.
  Local emails are returned for immediate processing.
  Remote emails are forwarded to their target nodes.
  """
  @spec process_routing([Email.t()]) :: {:local, [Email.t()]} | {:error, term()}
  def process_routing(emails) when is_list(emails) do
    case route_batch(emails) do
      %{} = routing_map ->
        # Send remote emails to their target nodes
        routing_map
        |> Enum.each(fn
          {:local, _local_emails} ->
            # Keep local emails for return
            :ok
            
          {{:remote, target_node}, remote_emails} ->
            send_batch_to_node(remote_emails, target_node)
            
          {{:error, reason}, failed_emails} ->
            Logger.error("Failed to route #{length(failed_emails)} emails: #{inspect(reason)}")
        end)
        
        # Return local emails for immediate processing
        local_emails = Map.get(routing_map, :local, [])
        {:local, local_emails}
    end
  end
  
  @doc """
  Receive a remote email forwarded from another node.
  This function is called via Node.route_cast from remote nodes.
  """
  @spec receive_remote_email(Email.t()) :: :ok
  def receive_remote_email(%Email{} = email) do
    Logger.debug("Received remote email from cluster")
    
    # Add to local queue for processing by local pipelines
    try do
      :ok = Epoxi.Queue.enqueue(:inbox, email)
      Logger.debug("Successfully queued remote email")
      :ok
    rescue
      error ->
        Logger.error("Failed to queue remote email: #{inspect(error)}")
        :ok  # Still return :ok to avoid remote node errors
    end
  end
  
  @doc """
  Receive a batch of remote emails forwarded from another node.
  More efficient than individual email processing.
  """
  @spec receive_remote_batch([Email.t()]) :: :ok
  def receive_remote_batch(emails) when is_list(emails) do
    Logger.debug("Received remote batch of #{length(emails)} emails from cluster")
    
    results = 
      emails
      |> Enum.map(fn email ->
        try do
          :ok = Epoxi.Queue.enqueue(:inbox, email)
          :ok
        rescue
          error -> 
            Logger.error("Failed to queue remote email: #{inspect(error)}")
            :error
        end
      end)
    
    success_count = Enum.count(results, & &1 == :ok)
    Logger.debug("Successfully queued #{success_count}/#{length(emails)} remote emails")
    
    :ok
  end
  
  @doc """
  Get routing statistics for monitoring and debugging.
  """
  @spec get_routing_stats() :: %{
    local_node: node(),
    available_nodes: [node()],
    total_ips: non_neg_integer(),
    ips_by_node: %{node() => [String.t()]}
  }
  def get_routing_stats() do
    all_cluster_ips = IpRegistry.get_all_cluster_ips()
    connected_nodes = [Node.self() | Node.list()]
    
    ips_by_node = 
      all_cluster_ips
      |> Enum.group_by(fn {_ip, node} -> node end, fn {ip, _node} -> ip end)
    
    %{
      local_node: Node.self(),
      available_nodes: connected_nodes,
      total_ips: length(all_cluster_ips),
      ips_by_node: ips_by_node
    }
  end
end