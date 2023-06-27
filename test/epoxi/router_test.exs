defmodule Epoxi.RouterTest do
  use ExUnit.Case, async: true

  # elixir --sname foo -S mix test 
  @tag :distributed
  test "routing request across nodes" do
    assert Epoxi.Router.route("local-foo.com", Kernel, :node, []) == :foo@jl
  end
end
