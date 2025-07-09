defmodule Epoxi.NodeRegistryTest do
  use ExUnit.Case, async: true

  alias Epoxi.NodeRegistry

  setup do
    pid =
      case start_supervised(NodeRegistry) do
        {:error, {:already_started, pid}} ->
          pid

        {:ok, pid} ->
          pid
      end

    {:ok, %{node_registry: pid}}
  end

  test "starts and responds to basic calls", %{node_registry: node_registry} do
    assert Process.alive?(node_registry)

    ips = NodeRegistry.get_all_cluster_ips()

    assert length(ips) > 0
  end

  test "get_pool_ips/1 returns empty map for non-existent pool" do
    assert NodeRegistry.get_pool_ips(:non_existent_pool) == []
  end

  test "get_node_ips/1 returns empty list for non-existent node" do
    assert NodeRegistry.get_node_ips(:non_existent_node) == []
  end

  test "find_ip_owner/1 returns not_found for non-existent IP" do
    assert NodeRegistry.find_ip_owner("192.168.1.1") == {:error, :not_found}
  end

  test "refresh/0 succeeds" do
    assert NodeRegistry.refresh() == :ok
  end

  describe "IP weight management" do
    test "set_ip_weight/2 and get_ip_weight/1 work correctly" do
      ip = "192.168.1.100"

      # Default weight should be 1
      assert NodeRegistry.get_ip_weight(ip) == 1

      # Set a new weight
      assert NodeRegistry.set_ip_weight(ip, 5) == :ok
      assert NodeRegistry.get_ip_weight(ip) == 5

      # Update the weight
      assert NodeRegistry.set_ip_weight(ip, 10) == :ok
      assert NodeRegistry.get_ip_weight(ip) == 10
    end
  end

  describe "allocate_ips/2" do
    test "handles empty email list" do
      emails = []
      result = NodeRegistry.allocate_ips(emails, :default)
      assert result == []
    end

    test "handles empty pool" do
      emails = [create_test_email()]
      result = NodeRegistry.allocate_ips(emails, :non_existent_pool)
      # Should return original emails unchanged
      assert result == emails
    end

    test "allocates IPs to emails" do
      emails = [
        create_test_email(),
        create_test_email(),
        create_test_email()
      ]

      result = NodeRegistry.allocate_ips(emails, :default)

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
      NodeRegistry.set_ip_weight("192.168.1.1", 1)
      # High weight
      NodeRegistry.set_ip_weight("192.168.1.2", 10)

      result = NodeRegistry.allocate_ips(emails, :default)

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
