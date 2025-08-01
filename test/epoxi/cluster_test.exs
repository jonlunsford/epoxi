defmodule Epoxi.ClusterTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "it returns a cluster with the current node placed in the default pool" do
      cluster = Epoxi.Cluster.init()

      node_names =
        cluster
        |> Epoxi.Cluster.find_nodes_in_pool(:default)
        |> Enum.map(& &1.name)

      assert Enum.member?(node_names, Node.self())
    end
  end

  describe "get_current_state/1" do
    test "it returns an updated cluster" do
      cluster =
        Epoxi.Cluster.new()
        |> Epoxi.Cluster.get_current_state()

      nodes = Epoxi.Cluster.find_nodes_in_pool(cluster, :default)

      assert Enum.all?(nodes, &(&1.status == :up))
      assert cluster.node_count == Enum.count(nodes)
    end
  end

  describe "add_node/2" do
    test "it adds nodes to the cluster, within their assigned pool" do
      node = Epoxi.Node.new(name: :foo, ip_pool: :high)

      cluster =
        Epoxi.Cluster.init()
        |> Epoxi.Cluster.add_node(node)

      nodes = Epoxi.Cluster.find_nodes_in_pool(cluster, :high)

      assert Enum.member?(nodes, node)
      assert cluster.node_count == 1
    end

    test "it adds nodes to the default pool if no pool is specified" do
      node = Epoxi.Node.new(name: :bar)

      cluster =
        Epoxi.Cluster.init()
        |> Epoxi.Cluster.add_node(node)

      nodes = Epoxi.Cluster.find_nodes_in_pool(cluster, :default)

      assert Enum.member?(nodes, node)
      assert cluster.node_count == 1
    end
  end

  describe "remove_node/2" do
    test "it removes nodes from the cluster" do
      node = Epoxi.Node.new(name: :foo)

      cluster =
        Epoxi.Cluster.init()
        |> Epoxi.Cluster.add_node(node)
        |> Epoxi.Cluster.remove_node(node)

      nodes = Epoxi.Cluster.find_nodes_in_pool(cluster, :default)

      refute Enum.member?(nodes, node)
    end

    test "it removes the node from ip_pools" do
      node = Epoxi.Node.new(name: :foo, ip_pool: :high)

      cluster =
        Epoxi.Cluster.init()
        |> Epoxi.Cluster.add_node(node)
        |> Epoxi.Cluster.remove_node(node)

      nodes = Epoxi.Cluster.find_nodes_in_pool(cluster, :high)

      refute Enum.member?(nodes, node)
      assert cluster.ip_pools[:high] == %{}
    end
  end

  describe "find_node/2" do
    test "it returns {:error, :not_found}" do
      assert {:error, :not_found} = Epoxi.Cluster.find_node(:foo)
    end

    test "returns nodes where their name matches the provided name" do
      node = Epoxi.Node.from_node(Node.self())

      result = Epoxi.Cluster.find_node(node.name)

      assert result.name == node.name
    end
  end

  describe "find_pool/2" do
    node = Epoxi.Node.from_node(Node.self())
    cluster = Epoxi.Cluster.init()

    node_names =
      cluster
      |> Epoxi.Cluster.find_nodes_in_pool(:default)
      |> Enum.map(& &1.name)

    assert Enum.member?(node_names, node.name)
  end

  describe "add_node_to_pool/3" do
    test "it creates a new pool if one does not exist" do
      node = Epoxi.Node.new(name: :foo, ip_pool: :high)

      cluster =
        Epoxi.Cluster.new(nodes: [node])
        |> Epoxi.Cluster.add_node_to_ip_pool(node)

      nodes = Epoxi.Cluster.find_nodes_in_pool(cluster, :high)

      assert nodes == [node]
    end
  end

  describe "select_node/2" do
    test "it returns nodes based on the provided strategy_fn" do
      node = Epoxi.Node.new(name: :foo)
      cluster = Epoxi.Cluster.new(nodes: [node])

      result = Epoxi.Cluster.select_node(cluster, fn [node | _] -> node end)

      assert ^node = result
    end
  end
end
