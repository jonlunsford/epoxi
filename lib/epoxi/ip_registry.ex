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

  defstruct cluster: %Epoxi.Cluster{}, ip_weights: %{}

  @type node_name :: atom()
  @type ip_address :: String.t()
  @type pool_name :: atom()
  @type ip_weight :: non_neg_integer()

  @type t :: %__MODULE__{
          cluster: Epoxi.Cluster.t(),
          ip_weights: %{ip_address() => ip_weight()}
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
  Allocate IP addresses from a pool to a list of emails.
  Updates each email's delivery field with the assigned IP and pool.
  Uses weighted distribution based on IP weights.
  """
  @spec allocate_ips([Epoxi.Email.t()], pool_name()) :: [Epoxi.Email.t()]
  def allocate_ips(emails, pool_name) do
    GenServer.call(__MODULE__, {:allocate_ips, emails, pool_name})
  end

  @doc """
  Set the weight for a specific IP address.
  Higher weights mean more emails will be assigned to this IP.
  """
  @spec set_ip_weight(ip_address(), ip_weight()) :: :ok
  def set_ip_weight(ip_address, weight) do
    GenServer.cast(__MODULE__, {:set_ip_weight, ip_address, weight})
  end

  @doc """
  Get the weight for a specific IP address.
  Returns 1 (default weight) if no weight is set.
  """
  @spec get_ip_weight(ip_address()) :: ip_weight()
  def get_ip_weight(ip_address) do
    GenServer.call(__MODULE__, {:get_ip_weight, ip_address})
  end

  @doc """
  Get all IP weights for a specific pool.
  """
  @spec get_pool_ip_weights(pool_name()) :: %{ip_address() => ip_weight()}
  def get_pool_ip_weights(pool_name) do
    GenServer.call(__MODULE__, {:get_pool_ip_weights, pool_name})
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
  def handle_call(
        {:allocate_ips, emails, pool_name},
        _from,
        %{cluster: cluster, ip_weights: ip_weights} = state
      ) do
    pool_ips = Epoxi.Cluster.get_pool_ips(cluster, pool_name)

    case pool_ips do
      [] ->
        {:reply, emails, state}

      _ ->
        weighted_ips = build_weighted_ip_list(pool_ips, ip_weights)
        allocated_emails = distribute_ips_to_emails(emails, weighted_ips, pool_name)
        {:reply, allocated_emails, state}
    end
  end

  @impl true
  def handle_call({:get_ip_weight, ip_address}, _from, %{ip_weights: ip_weights} = state) do
    weight = Map.get(ip_weights, ip_address, 1)
    {:reply, weight, state}
  end

  @impl true
  def handle_call(
        {:get_pool_ip_weights, pool_name},
        _from,
        %{cluster: cluster, ip_weights: ip_weights} = state
      ) do
    pool_ips = Epoxi.Cluster.get_pool_ips(cluster, pool_name)
    pool_weights = Map.take(ip_weights, pool_ips)
    {:reply, pool_weights, state}
  end

  @impl true
  def handle_cast(:refresh, %{cluster: cluster} = state) do
    cur_cluster = Epoxi.Cluster.get_current_state(cluster)
    new_state = %{state | cluster: cur_cluster}
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:set_ip_weight, ip_address, weight}, %{ip_weights: ip_weights} = state) do
    new_ip_weights = Map.put(ip_weights, ip_address, weight)
    {:noreply, %{state | ip_weights: new_ip_weights}}
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

    node = Epoxi.Node.new(name: node_name)
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

  # Build a weighted list of IPs based on their weights
  # Each IP appears in the list according to its weight
  defp build_weighted_ip_list(pool_ips, ip_weights) do
    pool_ips
    |> Enum.flat_map(fn ip ->
      weight = Map.get(ip_weights, ip, 1)
      List.duplicate(ip, weight)
    end)
    |> Enum.shuffle()
  end

  # Distribute IPs to emails using weighted round-robin
  defp distribute_ips_to_emails(emails, weighted_ips, pool_name) do
    case weighted_ips do
      [] ->
        emails

      _ ->
        emails
        |> Enum.with_index()
        |> Enum.map(fn {email, index} ->
          ip = Enum.at(weighted_ips, rem(index, length(weighted_ips)))
          delivery_config = %{ip: ip, ip_pool: Atom.to_string(pool_name)}
          %{email | delivery: delivery_config}
        end)
    end
  end
end
