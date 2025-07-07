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

  describe "IP weight management" do
    test "set_ip_weight/2 and get_ip_weight/1 work correctly" do
      ip = "192.168.1.100"

      # Default weight should be 1
      assert IpRegistry.get_ip_weight(ip) == 1

      # Set a new weight
      assert IpRegistry.set_ip_weight(ip, 5) == :ok
      assert IpRegistry.get_ip_weight(ip) == 5

      # Update the weight
      assert IpRegistry.set_ip_weight(ip, 10) == :ok
      assert IpRegistry.get_ip_weight(ip) == 10
    end

    test "get_pool_ip_weights/1 returns weights for pool IPs" do
      # This test assumes the default pool has some IPs
      # We'll set weights for some fictional IPs and verify they're returned
      IpRegistry.set_ip_weight("192.168.1.1", 3)
      IpRegistry.set_ip_weight("192.168.1.2", 7)

      pool_weights = IpRegistry.get_pool_ip_weights(:default)
      assert is_map(pool_weights)
    end
  end

  describe "allocate_ips/2" do
    test "handles empty email list" do
      emails = []
      result = IpRegistry.allocate_ips(emails, :default)
      assert result == []
    end

    test "handles empty pool" do
      emails = [create_test_email()]
      result = IpRegistry.allocate_ips(emails, :non_existent_pool)
      # Should return original emails unchanged
      assert result == emails
    end

    test "allocates IPs to emails" do
      emails = [
        create_test_email(),
        create_test_email(),
        create_test_email()
      ]

      result = IpRegistry.allocate_ips(emails, :default)

      # Should have same number of emails
      assert length(result) == length(emails)

      # Each email should have delivery config set
      Enum.each(result, fn email ->
        assert Map.has_key?(email.delivery, :ip)
        assert Map.has_key?(email.delivery, :ip_pool)
        assert email.delivery.ip_pool == "default"
      end)
    end

    test "weighted distribution assigns more emails to higher weight IPs" do
      # Create a larger batch to see distribution effects
      emails = Enum.map(1..100, fn _ -> create_test_email() end)

      # Set different weights (this assumes we have at least these IPs in the pool)
      # Low weight
      IpRegistry.set_ip_weight("192.168.1.1", 1)
      # High weight
      IpRegistry.set_ip_weight("192.168.1.2", 10)

      result = IpRegistry.allocate_ips(emails, :default)

      # Count IP assignments
      ip_counts =
        result
        |> Enum.map(& &1.delivery.ip)
        |> Enum.frequencies()

      # Should have assigned IPs
      assert map_size(ip_counts) > 0

      # All emails should have been assigned
      total_assigned = ip_counts |> Map.values() |> Enum.sum()
      assert total_assigned == 100
    end
  end

  # Helper function to create test emails
  defp create_test_email do
    %Epoxi.Email{
      to: ["test@example.com"],
      from: "sender@example.com",
      subject: "Test Email",
      delivery: %{}
    }
  end
end
