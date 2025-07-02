defmodule Epoxi.IpRegistry do
  @moduledoc """
  Cluster-wide registry for tracking IP address ownership across nodes.

  This GenServer maintains a distributed view of which IPs are available
  on which nodes, automatically updating when nodes join or leave the cluster.

  It delegates to {Epoxi.Cluster} for function calling.

  Key responsibilities:
  - Track IP ownership per node
  - Monitor node up/down events
  - Provide cluster-wide IP discovery
  - Support IP pool aggregation
  """

  use GenServer
  require Logger

  defstruct cluster: %Epoxi.Cluster{}

  @type node_name :: atom()
  @type ip_address :: String.t()
  @type pool_name :: atom()

  @type t :: %__MODULE__{
          cluster: Epoxi.Cluster.t()
        }

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

  @impl true
  def init(_opts) do
    :ok = :net_kernel.monitor_nodes(true, [:nodedown_reason])

    state = %__MODULE__{
      cluster: Epoxi.Cluster.init()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_pool_ips, pool_name}, _from, %{cluster: cluster} = state) do
    pool_ips = Epoxi.Cluster.get_pool_ips(cluster, pool_name)
    {:reply, pool_ips, state}
  end

  @impl true
  def handle_call({:get_node_ips, node_name}, _from, %{cluster: cluster} = state) do
    ips =
      case Epoxi.Cluster.find_node_in_cluster(cluster, node_name) do
        {:ok, node} -> node.ip_addresses
        {:error, :not_found} -> []
      end

    {:reply, ips, state}
  end

  @impl true
  def handle_call({:find_ip_owner, ip_address}, _from, %{cluster: cluster} = state) do
    result = Epoxi.Cluster.find_ip_owner(cluster, ip_address)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_all_cluster_ips, _from, %{cluster: cluster} = state) do
    all_ips = Epoxi.Cluster.get_all_ips(cluster)
    {:reply, all_ips, state}
  end

  @impl true
  def handle_cast(:refresh, %{cluster: cluster} = state) do
    cur_cluster = Epoxi.Cluster.get_current_state(cluster)
    new_state = %{state | cluster: cur_cluster}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:nodeup, node_name, _info}, %{cluster: cluster} = state) do
    Logger.info("Node #{node_name} joined cluster, discovering IPs")

    node = Epoxi.Node.from_node(node_name)

    Logger.info("Discovered IPs: #{node.ip_addresses}")

    new_cluster = Epoxi.Cluster.add_node(cluster, node)
    {:noreply, %{state | cluster: new_cluster}}
  end

  @impl true
  def handle_info({:nodedown, node_name, reason}, %{cluster: cluster} = state) do
    Logger.info("Node #{node_name} left cluster (reason: #{inspect(reason)}), removing IPs")

    node = Epoxi.Node.from_node(node_name)
    new_cluster = Epoxi.Cluster.remove_node(cluster, node)

    {:noreply, %{state | cluster: new_cluster}}
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
end
