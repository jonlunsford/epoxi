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

      :ets.insert_new(:epoxi_node_pipelines, {pipeline_info.name, pipeline_info})

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

      :ets.insert_new(:epoxi_node_pipelines, {pipeline_info.name, pipeline_info})
      assert length(Node.get_pipelines()) == 1

      :ets.delete(:epoxi_node_pipelines, :test_pipeline)
      assert Enum.empty?(Node.get_pipelines())
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

      :ets.insert_new(:epoxi_node_pipelines, {pipeline1.name, pipeline1})
      :ets.insert_new(:epoxi_node_pipelines, {pipeline2.name, pipeline2})

      gmail_pipelines = Node.find_pipelines_by_routing_key("gmail_com_192_168_1_1")
      assert length(gmail_pipelines) == 1
      assert hd(gmail_pipelines).name == :pipeline1

      yahoo_pipelines = Node.find_pipelines_by_routing_key("yahoo_com_192_168_1_2")
      assert length(yahoo_pipelines) == 1
      assert hd(yahoo_pipelines).name == :pipeline2

      nonexistent_pipelines = Node.find_pipelines_by_routing_key("nonexistent_com")
      assert Enum.empty?(nonexistent_pipelines)
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

      :ets.insert_new(:epoxi_node_pipelines, {pipeline_info.name, pipeline_info})

      current_node = Node.current()
      assert length(current_node.pipelines) >= 1

      # Find our test pipeline
      test_pipeline = Enum.find(current_node.pipelines, &(&1.name == :test_pipeline))
      assert test_pipeline != nil
      assert test_pipeline.routing_key == "test_domain_com_192_168_1_1"
    end
  end
end
