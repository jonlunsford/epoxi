defmodule Epoxi.NodePipelineTest do
  use ExUnit.Case, async: false
  
  alias Epoxi.Node
  
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
  
  describe "pipeline registration" do
    test "registers and retrieves pipelines" do
      pipeline_info = %{
        name: :test_pipeline,
        routing_key: "test_domain_com_192_168_1_1",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      assert :ok = Node.register_pipeline(pipeline_info)
      
      pipelines = Node.get_pipelines()
      assert length(pipelines) == 1
      assert hd(pipelines) == pipeline_info
    end
    
    test "unregisters pipelines" do
      pipeline_info = %{
        name: :test_pipeline,
        routing_key: "test_domain_com_192_168_1_1",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      Node.register_pipeline(pipeline_info)
      assert length(Node.get_pipelines()) == 1
      
      Node.unregister_pipeline(:test_pipeline)
      assert length(Node.get_pipelines()) == 0
    end
    
    test "finds pipelines by routing key" do
      pipeline1 = %{
        name: :pipeline1,
        routing_key: "gmail_com_192_168_1_1",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      pipeline2 = %{
        name: :pipeline2,
        routing_key: "yahoo_com_192_168_1_2",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      Node.register_pipeline(pipeline1)
      Node.register_pipeline(pipeline2)
      
      gmail_pipelines = Node.find_pipelines_by_routing_key("gmail_com_192_168_1_1")
      assert length(gmail_pipelines) == 1
      assert hd(gmail_pipelines).name == :pipeline1
      
      yahoo_pipelines = Node.find_pipelines_by_routing_key("yahoo_com_192_168_1_2")
      assert length(yahoo_pipelines) == 1
      assert hd(yahoo_pipelines).name == :pipeline2
      
      nonexistent_pipelines = Node.find_pipelines_by_routing_key("nonexistent_com")
      assert length(nonexistent_pipelines) == 0
    end
  end
  
  describe "node state with pipelines" do
    test "current node includes pipeline information" do
      pipeline_info = %{
        name: :test_pipeline,
        routing_key: "test_domain_com_192_168_1_1",
        pid: self(),
        policy: nil,
        started_at: DateTime.utc_now()
      }
      
      Node.register_pipeline(pipeline_info)
      
      current_node = Node.current()
      assert length(current_node.pipelines) >= 1
      
      # Find our test pipeline
      test_pipeline = Enum.find(current_node.pipelines, & &1.name == :test_pipeline)
      assert test_pipeline != nil
      assert test_pipeline.routing_key == "test_domain_com_192_168_1_1"
    end
  end
end
