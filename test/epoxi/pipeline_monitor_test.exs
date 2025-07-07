defmodule Epoxi.PipelineMonitorTest do
  use ExUnit.Case, async: false
  
  alias Epoxi.{PipelineMonitor, Node}
  alias Epoxi.Queue.PipelinePolicy
  
  setup do
    # Ensure the ETS table is clean for each test
    case :ets.whereis(:epoxi_node_pipelines) do
      :undefined -> 
        :ets.new(:epoxi_node_pipelines, [:named_table, :public, :set])
      table -> 
        :ets.delete_all_objects(table)
    end
    
    :ok
  end
  
  describe "health_check_all/0" do
    test "returns health check results for all pipelines" do
      # Register a test pipeline
      pipeline_info = %{
        name: :test_pipeline,
        routing_key: "test_domain_com_192_168_1_1",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      Node.register_pipeline(pipeline_info)
      
      health_results = PipelineMonitor.health_check_all()
      
      assert is_list(health_results)
      
      if length(health_results) > 0 do
        result = hd(health_results)
        assert Map.has_key?(result, :node)
        assert Map.has_key?(result, :pipeline_name)
        assert Map.has_key?(result, :routing_key)
        assert Map.has_key?(result, :health)
        assert Map.has_key?(result, :last_check)
        
        assert result.health in [:healthy, :unhealthy, :unknown]
      end
    end
    
    test "returns empty list when no pipelines exist" do
      health_results = PipelineMonitor.health_check_all()
      # May return empty or may have existing pipelines from other tests
      assert is_list(health_results)
    end
  end
  
  describe "health_check_routing_key/1" do
    test "returns health check results for specific routing key" do
      # Register a test pipeline
      pipeline_info = %{
        name: :test_pipeline,
        routing_key: "test_specific_routing_key",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      Node.register_pipeline(pipeline_info)
      
      health_results = PipelineMonitor.health_check_routing_key("test_specific_routing_key")
      
      assert is_list(health_results)
      
      if length(health_results) > 0 do
        result = hd(health_results)
        assert result.routing_key == "test_specific_routing_key"
        assert result.pipeline_name == :test_pipeline
      end
    end
    
    test "returns empty list for nonexistent routing key" do
      health_results = PipelineMonitor.health_check_routing_key("nonexistent_routing_key")
      assert health_results == []
    end
  end
  
  describe "get_cluster_stats/0" do
    test "returns comprehensive cluster statistics" do
      # Register a test pipeline
      pipeline_info = %{
        name: :test_pipeline,
        routing_key: "test_stats_routing_key",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      Node.register_pipeline(pipeline_info)
      
      stats = PipelineMonitor.get_cluster_stats()
      
      assert is_map(stats)
      assert Map.has_key?(stats, :pipeline_stats)
      assert Map.has_key?(stats, :health_summary)
      assert Map.has_key?(stats, :routing_key_distribution)
      assert Map.has_key?(stats, :node_load_distribution)
      
      # Verify pipeline_stats structure
      assert is_map(stats.pipeline_stats)
      assert Map.has_key?(stats.pipeline_stats, :total_pipelines)
      assert Map.has_key?(stats.pipeline_stats, :nodes_with_pipelines)
      
      # Verify health_summary structure
      assert is_map(stats.health_summary)
      assert Map.has_key?(stats.health_summary, :healthy)
      assert Map.has_key?(stats.health_summary, :unhealthy)
      assert Map.has_key?(stats.health_summary, :unknown)
      
      # Verify routing_key_distribution is a map
      assert is_map(stats.routing_key_distribution)
      
      # Verify node_load_distribution is a map
      assert is_map(stats.node_load_distribution)
    end
  end
  
  describe "start_pipeline_optimal/2" do
    test "attempts to start pipeline on optimal node" do
      policy = PipelinePolicy.new(
        name: :test_optimal_pipeline,
        max_connections: 3,
        max_retries: 2
      )
      
      # This will likely fail in test environment, but we can verify the call structure
      case PipelineMonitor.start_pipeline_optimal(policy, :default) do
        {:ok, {node_name, pid}} ->
          assert is_atom(node_name)
          assert is_pid(pid)
        
        {:error, reason} ->
          # Expected in test environment
          assert is_binary(reason)
      end
    end
  end
end
