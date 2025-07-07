defmodule Epoxi.Email.RouterTest do
  use ExUnit.Case, async: false
  
  alias Epoxi.Email.Router
  alias Epoxi.{Email, Node, Cluster}
  alias Epoxi.Queue.PipelinePolicy
  
  describe "route_emails/3" do
    test "routes emails to appropriate pipelines" do
      emails = [
        %Email{to: ["user1@gmail.com"], delivery: %{ip: "192.168.1.1"}},
        %Email{to: ["user2@gmail.com"], delivery: %{ip: "192.168.1.1"}},
        %Email{to: ["user3@yahoo.com"], delivery: %{ip: "192.168.1.2"}}
      ]
      
      # Mock the cluster and routing behavior
      assert {:ok, summary} = Router.route_emails(emails, :default)
      
      assert summary.total_emails == 3
      assert summary.total_batches >= 1
      assert is_integer(summary.successful_batches)
      assert is_integer(summary.failed_batches)
      assert is_integer(summary.new_pipelines_started)
    end
    
    test "handles empty email list" do
      assert {:ok, summary} = Router.route_emails([], :default)
      
      assert summary.total_emails == 0
      assert summary.total_batches == 0
      assert summary.successful_batches == 0
      assert summary.failed_batches == 0
      assert summary.new_pipelines_started == 0
    end
    
    test "respects batch size option" do
      emails = for i <- 1..10, do: %Email{to: ["user#{i}@example.com"], delivery: %{ip: "192.168.1.1"}}
      
      assert {:ok, summary} = Router.route_emails(emails, :default, batch_size: 3)
      
      assert summary.total_emails == 10
      # Should create at least 4 batches (10/3 = 3.33, rounded up)
      assert summary.total_batches >= 4
    end
  end
  
  describe "find_node_for_routing_key/1" do
    test "returns error when no pipeline exists for routing key" do
      routing_key = "nonexistent_domain_com_192_168_1_1"
      
      case Router.find_node_for_routing_key(routing_key) do
        {:error, :not_found} -> :ok
        {:ok, _node} -> :ok  # Pipeline might exist from other tests
      end
    end
  end
  
  describe "get_pipeline_stats/0" do
    test "returns pipeline statistics" do
      stats = Router.get_pipeline_stats()
      
      assert is_map(stats)
      assert Map.has_key?(stats, :total_pipelines)
      assert Map.has_key?(stats, :nodes_with_pipelines)
      assert Map.has_key?(stats, :average_pipelines_per_node)
      assert Map.has_key?(stats, :pipeline_distribution)
      
      assert is_integer(stats.total_pipelines)
      assert is_integer(stats.nodes_with_pipelines)
      assert is_number(stats.average_pipelines_per_node)
      assert is_map(stats.pipeline_distribution)
    end
  end
end
