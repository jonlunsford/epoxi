defmodule Epoxi.Queue.ProducerTest do
  use ExUnit.Case, async: true

  alias Epoxi.Queue.Producer

  test "init/1 raises when queue is not provided" do
    assert_raise ArgumentError, ~r/required :queue option not found/, fn ->
      Producer.init([])
    end
  end
end
