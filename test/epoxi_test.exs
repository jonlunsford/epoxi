defmodule EpoxiTest do
  use ExUnit.Case
  doctest Epoxi

  test "greets the world" do
    assert Epoxi.hello() == :world
  end
end
