defmodule Epoxi.IpRegistryTest do
  use ExUnit.Case, async: true

  alias Epoxi.IpRegistry

  setup do
    pid =
      case start_supervised(IpRegistry) do
        {:error, {:already_started, pid}} ->
          pid

        {:ok, pid} ->
          pid
      end

    {:ok, %{ip_registry: pid}}
  end

  test "starts and responds to basic calls", %{ip_registry: ip_registry} do
    assert Process.alive?(ip_registry)

    ips = IpRegistry.get_all_cluster_ips()

    assert length(ips) > 0
  end

  test "get_pool_ips/1 returns empty map for non-existent pool" do
    assert IpRegistry.get_pool_ips(:non_existent_pool) == []
  end

  test "get_node_ips/1 returns empty list for non-existent node" do
    assert IpRegistry.get_node_ips(:non_existent_node) == []
  end

  test "find_ip_owner/1 returns not_found for non-existent IP" do
    assert IpRegistry.find_ip_owner("192.168.1.1") == {:error, :not_found}
  end

  test "refresh/0 succeeds" do
    assert IpRegistry.refresh() == :ok
  end
end
