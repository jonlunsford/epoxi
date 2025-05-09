defmodule Epoxi.ClusterTest do
  use ExUnit.Case, async: true

  describe "state/1" do
    test "it returns an updated cluster" do
      cluster =
        Epoxi.Cluster.new()
        |> Epoxi.Cluster.state()

      [node] = cluster.nodes

      assert node.status == :up
      assert cluster.node_count == 1
    end
  end

  describe "find_node/2" do
    test "it returns {:error, :not_found}" do
      cluster = Epoxi.Cluster.new()

      assert {:error, :not_found} = Epoxi.Cluster.find_node(cluster, :foo)
    end

    test "returns nodes where their name matches the provided name" do
      node = Epoxi.Node.new(name: :foo)
      cluster = Epoxi.Cluster.new(nodes: [node])

      assert ^node = Epoxi.Cluster.find_node(cluster, node.name)
    end
  end
end
