defmodule Epoxi.Node do
  @moduledoc """
  Represents and manages Epoxi.Node instances within a distributed cluster.

  This module provides functionality for:
  - Creating and managing node representations
  - Facilitating inter-node communication via RPC calls
  - Monitoring node state and network information
  - Handling both synchronous and asynchronous operations across nodes

  It serves as a key component for maintaining distributed functionality in the Epoxi system.
  """
  defstruct [:name, :emails_queued, :last_seen, :ip_addresses, status: :unknown]

  require Logger

  @type node_status :: :up | :down | :unknown
  @type node_state :: map()
  @type ip_address :: String.t()

  @type t :: %__MODULE__{
          emails_queued: non_neg_integer(),
          name: atom(),
          status: node_status(),
          ip_addresses: [ip_address()],
          last_seen: Calendar.datetime()
        }

  @doc """
  Creates a new Epoxi.Node struct with the given attributes.

  ## Parameters
    * `attrs` - A keyword list of attributes to initialize the node with.

  ## Examples
      iex> Epoxi.Node.new(name: :node1, status: :up)
      %Epoxi.Node{name: :node1, status: :up, emails_queued: nil, ip_addresses: nil, last_seen: nil}
  """
  def new(attrs \\ []) do
    struct(Epoxi.Node, attrs)
  end

  @doc """
  Sends an asynchronous (cast) request to the target node.

  Determines if the target is the local node or a remote node and routes
  the function call appropriately. For remote nodes, this uses erpc.cast.

  ## Parameters
    * `target_node` - The Epoxi.Node struct representing the destination node
    * `mod` - The module containing the function to call
    * `fun` - The function to call
    * `args` - Arguments to pass to the function

  ## Examples
      iex> target = Epoxi.Node.new(name: :node2)
      iex> Epoxi.Node.route_cast(target, MyModule, :process_async, [id: 123])
      {:ok, :message_sent_async}
  """
  @spec route_cast(
          target_node :: t(),
          mod :: module(),
          fun :: fun(),
          args ::
            Keyword.t()
        ) :: {:ok, :message_sent_async} | {:error, any()}
  def route_cast(%Epoxi.Node{} = target_node, mod, fun, args) do
    case local?(target_node) do
      true -> apply(mod, fun, args)
      false -> erpc_cast(target_node, mod, fun, args)
    end
  end

  @doc """
  Sends a synchronous (call) request to the target node and waits for the response.

  Determines if the target is the local node or a remote node and routes
  the function call appropriately. For remote nodes, this uses erpc.call.

  ## Parameters
    * `target_node` - The Epoxi.Node struct representing the destination node
    * `mod` - The module containing the function to call
    * `fun` - The function to call
    * `args` - Arguments to pass to the function

  ## Examples
      iex> target = Epoxi.Node.new(name: :node2)
      iex> Epoxi.Node.route_call(target, MyModule, :get_data, [id: 123])
      {:ok, %{result: "data"}}
  """
  @spec route_call(
          target_node :: t(),
          mod :: module(),
          fun :: fun(),
          args ::
            Keyword.t()
        ) :: {:ok, any()} | {:error, any()}
  def route_call(%Epoxi.Node{} = target_node, mod, fun, args) do
    case local?(target_node) do
      true -> apply(mod, fun, args)
      false -> erpc_call(target_node, mod, fun, args)
    end
  end

  @doc """
  Returns the current state of the local node.

  Collects important metrics about the node's operation, such as the number of
  emails currently in the queue.

  ## Returns
    * A map containing node state information

  ## Examples
      iex> Epoxi.Node.state()
      %{emails_queued: 42}
  """
  @spec state() :: node_state()
  def state() do
    # TODO: Create module to return "current stats" per node.
    %{
      emails_queued: Epoxi.Queue.length(:inbox)
    }
  end

  @doc """
  Retrieves a list of IP addresses for the network interfaces on the target node.

  Uses route_call to execute the request on the appropriate node, then formats
  the interface information to return only the IPv4 addresses.

  ## Parameters
    * `target_node` - The Epoxi.Node struct representing the node to query

  ## Returns
    * `{:ok, addresses}` - List of IP addresses as strings on success
    * `{:error, reason}` - Error information if the call fails

  ## Examples
      iex> node = Epoxi.Node.new(name: :node1)
      iex> Epoxi.Node.interfaces(node)
      {:ok, ["192.168.1.100", "127.0.0.1"]}
  """
  @spec interfaces(targe_node :: t()) :: {:ok, [ip_address()], {:error, term()}}
  def interfaces(%Epoxi.Node{} = target_node) do
    case route_call(target_node, :inet, :getifaddrs, []) do
      {:ok, interfaces} ->
        result = format_interface_addresses(interfaces)
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp local?(%Epoxi.Node{name: node_name}) do
    Node.self() == node_name
  end

  defp erpc_call(%Epoxi.Node{name: node_name}, mod, fun, args) do
    case :erpc.call(node_name, mod, fun, args) do
      {:badrpc, reason} ->
        Logger.error("RPC call to #{node_name} failed: #{inspect(reason)}")
        {:error, reason}

      result ->
        {:ok, result}
    end
  end

  defp erpc_cast(%Epoxi.Node{name: node_name}, mod, fun, args) do
    case :erpc.cast(node_name, mod, fun, args) do
      {:badrpc, reason} ->
        Logger.error("RPC call to #{node_name} failed: #{inspect(reason)}")
        {:error, reason}

      :ok ->
        {:ok, :message_sent_async}
    end
  end

  defp format_interface_addresses(interfaces) do
    interfaces
    |> Enum.flat_map(fn {_if_name, if_opts} ->
      addr = Keyword.get(if_opts, :addr)

      case addr do
        {a, b, c, d} -> ["#{a}.#{b}.#{c}.#{d}"]
        _ -> []
      end
    end)
  end
end
