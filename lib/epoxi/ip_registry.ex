defmodule Epoxi.IpRegistry do
  @moduledoc """
  Cluster-wide registry for tracking IP address ownership across nodes.
  
  This GenServer maintains a distributed view of which IPs are available
  on which nodes, automatically updating when nodes join or leave the cluster.
  
  Key responsibilities:
  - Track IP ownership per node
  - Monitor node up/down events
  - Provide cluster-wide IP discovery
  - Support IP pool aggregation
  """
  
  use GenServer
  require Logger
  
  
  defstruct [
    :monitor_ref,
    node_ips: %{},
    pools: %{}
  ]
  
  @type node_name :: atom()
  @type ip_address :: String.t()
  @type pool_name :: atom()
  
  @type t :: %__MODULE__{
    monitor_ref: reference() | nil,
    node_ips: %{node_name() => [ip_address()]},
    pools: %{pool_name() => %{node_name() => [ip_address()]}}
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Get all IPs available in a specific pool across the cluster.
  Returns a map of node_name => [ip_addresses]
  """
  @spec get_pool_ips(pool_name()) :: %{node_name() => [ip_address()]}
  def get_pool_ips(pool_name) do
    GenServer.call(__MODULE__, {:get_pool_ips, pool_name})
  end
  
  @doc """
  Get all available IPs for a specific node.
  """
  @spec get_node_ips(node_name()) :: [ip_address()]
  def get_node_ips(node_name) do
    GenServer.call(__MODULE__, {:get_node_ips, node_name})
  end
  
  @doc """
  Find which node owns a specific IP address.
  """
  @spec find_ip_owner(ip_address()) :: {:ok, node_name()} | {:error, :not_found}
  def find_ip_owner(ip_address) do
    GenServer.call(__MODULE__, {:find_ip_owner, ip_address})
  end
  
  @doc """
  Get all available IPs across the entire cluster.
  Returns a flat list of all IPs with their owning nodes.
  """
  @spec get_all_cluster_ips() :: [{ip_address(), node_name()}]
  def get_all_cluster_ips() do
    GenServer.call(__MODULE__, :get_all_cluster_ips)
  end
  
  @doc """
  Force refresh of IP information for all connected nodes.
  """
  @spec refresh() :: :ok
  def refresh() do
    GenServer.cast(__MODULE__, :refresh)
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    # Monitor node changes
    :ok = :net_kernel.monitor_nodes(true, [:nodedown_reason])
    
    state = %__MODULE__{
      monitor_ref: nil,
      node_ips: %{},
      pools: %{}
    }
    
    # Initial discovery of all current nodes
    send(self(), :initial_discovery)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:get_pool_ips, pool_name}, _from, state) do
    pool_ips = Map.get(state.pools, pool_name, %{})
    {:reply, pool_ips, state}
  end
  
  @impl true
  def handle_call({:get_node_ips, node_name}, _from, state) do
    ips = Map.get(state.node_ips, node_name, [])
    {:reply, ips, state}
  end
  
  @impl true
  def handle_call({:find_ip_owner, ip_address}, _from, state) do
    result = 
      Enum.find_value(state.node_ips, {:error, :not_found}, fn {node_name, ips} ->
        if ip_address in ips do
          {:ok, node_name}
        else
          nil
        end
      end)
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:get_all_cluster_ips, _from, state) do
    all_ips = 
      Enum.flat_map(state.node_ips, fn {node_name, ips} ->
        Enum.map(ips, fn ip -> {ip, node_name} end)
      end)
    
    {:reply, all_ips, state}
  end
  
  @impl true
  def handle_cast(:refresh, state) do
    new_state = discover_all_nodes(state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:initial_discovery, state) do
    new_state = discover_all_nodes(state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:nodeup, node_name, _info}, state) do
    Logger.info("Node #{node_name} joined cluster, discovering IPs")
    new_state = discover_node_ips(state, node_name)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:nodedown, node_name, reason}, state) do
    Logger.info("Node #{node_name} left cluster (reason: #{inspect(reason)}), removing IPs")
    new_state = remove_node(state, node_name)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("IpRegistry received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  @impl true
  def terminate(_reason, _state) do
    :net_kernel.monitor_nodes(false)
    :ok
  end
  
  # Private Functions
  
  defp discover_all_nodes(state) do
    connected_nodes = [Node.self() | Node.list()]
    
    Enum.reduce(connected_nodes, state, fn node_name, acc_state ->
      discover_node_ips(acc_state, node_name)
    end)
  end
  
  defp discover_node_ips(state, node_name) do
    case Epoxi.Node.from_node(node_name) |> Epoxi.Node.interfaces() do
      {:ok, ips} ->
        Logger.debug("Discovered IPs for #{node_name}: #{inspect(ips)}")
        
        # Update node IPs
        new_node_ips = Map.put(state.node_ips, node_name, ips)
        
        # Update pools - get the node's pool assignment
        node = Epoxi.Node.from_node(node_name)
        pool_name = node.ip_pool
        
        new_pools = update_pool_ips(state.pools, pool_name, node_name, ips)
        
        %{state | node_ips: new_node_ips, pools: new_pools}
        
      {:error, reason} ->
        Logger.warning("Failed to discover IPs for #{node_name}: #{inspect(reason)}")
        state
    end
  end
  
  defp update_pool_ips(pools, pool_name, node_name, ips) do
    pools
    |> Map.put_new(pool_name, %{})
    |> put_in([pool_name, node_name], ips)
  end
  
  defp remove_node(state, node_name) do
    # Remove from node_ips
    new_node_ips = Map.delete(state.node_ips, node_name)
    
    # Remove from all pools
    new_pools = 
      Enum.into(state.pools, %{}, fn {pool_name, pool_nodes} ->
        {pool_name, Map.delete(pool_nodes, node_name)}
      end)
    
    %{state | node_ips: new_node_ips, pools: new_pools}
  end
end