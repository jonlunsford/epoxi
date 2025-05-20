defmodule Epoxi.NodeTest do
  use ExUnit.Case, async: true

  describe "from_node" do
    test "it returns a struct" do
      assert %Epoxi.Node{} = Epoxi.Node.from_node(Node.self())
    end
  end

  describe "route_cast/4" do
    test "routes function call to local node" do
      node = Epoxi.Node.new(name: Node.self())

      assert Epoxi.Node.route_cast(node, Kernel, :node, []) == node.name
    end

    @tag :distributed
    test "routing request across nodes" do
      # mix test --include distributed
      node = Epoxi.Node.new(name: Node.self())
      assert Epoxi.Node.route_call(node, Kernel, :node, []) == node.name
    end
  end

  describe "route_call/4" do
    test "routes function call to local node" do
      node = Epoxi.Node.new(name: Node.self())

      assert Epoxi.Node.route_call(node, Kernel, :node, []) == node.name
    end
  end

  describe "interfaces/0" do
    test "it returns a list of IPv4 addresses" do
      node = Epoxi.Node.new(name: Node.self())

      {:ok, ip_addresses} = Epoxi.Node.interfaces(node)

      assert is_list(ip_addresses)
    end
  end
end
