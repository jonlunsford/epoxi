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
  defstruct [
    :name,
    :emails_queued,
    :last_seen,
    :ip_addresses,
    ip_pool: :default,
    status: :unknown
  ]

  require Logger

  @type node_status :: :up | :down | :unknown
  @type ip_address :: String.t()

  @type t :: %__MODULE__{
          emails_queued: non_neg_integer(),
          name: atom(),
          status: node_status(),
          ip_addresses: [ip_address()],
          ip_pool: atom(),
          last_seen: Calendar.datetime()
        }

  def new(attrs \\ []) do
    struct(Epoxi.Node, attrs)
  end

  @spec from_node(node()) :: t()
  def from_node(node) do
    new(name: node)
    |> state()
  end

  @spec current :: t()
  def current do
    Node.self()
    |> from_node()
  end

  @spec route_cast(
          target_node :: t(),
          mod :: module(),
          fun :: fun(),
          args ::
            Keyword.t()
        ) :: {:ok, :message_sent_async} | {:error, any()} | any()
  def route_cast(%Epoxi.Node{} = target_node, mod, fun, args) do
    case local?(target_node) do
      true -> apply(mod, fun, args)
      false -> erpc_cast(target_node, mod, fun, args)
    end
  end

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

  @spec state(target_node :: t()) :: t()
  def state(%Epoxi.Node{} = node) do
    case local?(node) do
      true ->
        put_state(node, %{status: :up, last_seen: DateTime.utc_now()})

      false ->
        {:ok, result} = erpc_call(node, Epoxi.Node, :state, [node])
        result
    end
  end

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
    start_time = System.monotonic_time()

    case :erpc.call(node_name, mod, fun, args) do
      {:badrpc, reason} ->
        Logger.error("RPC call to #{node_name} failed: #{inspect(reason)}")
        record_routing_telemetry(self(), node_name, start_time, reason)
        {:error, reason}

      result ->
        record_routing_telemetry(self(), node_name, start_time, result)
        {:ok, result}
    end
  end

  defp erpc_cast(%Epoxi.Node{name: node_name}, mod, fun, args) do
    start_time = System.monotonic_time()

    case :erpc.cast(node_name, mod, fun, args) do
      {:badrpc, reason} ->
        Logger.error("RPC call to #{node_name} failed: #{inspect(reason)}")
        record_routing_telemetry(self(), node_name, start_time, reason)
        {:error, reason}

      :ok ->
        {:ok, :message_sent_async}
    end
  end

  defp put_state(%Epoxi.Node{} = node, additional_state) do
    {:ok, ips} = interfaces(node)

    node
    |> Map.put(:ip_addresses, ips)
    |> Map.merge(additional_state)
  end

  defp record_routing_telemetry(source_node, target_node, start_time, result) do
    end_time = System.monotonic_time()
    duration = end_time - start_time

    :telemetry.execute(
      [:epoxi, :router, :route, :count],
      %{count: 1},
      %{source_node: source_node, target_node: target_node, result: result}
    )

    :telemetry.execute(
      [:epoxi, :router, :route, :latency],
      %{duration: duration},
      %{source_node: source_node, target_node: target_node}
    )
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
