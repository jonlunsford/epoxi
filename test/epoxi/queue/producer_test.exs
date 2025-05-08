defmodule Epoxi.Queue.ProducerTest do
  use ExUnit.Case, async: true

  alias Epoxi.Queue.Producer

  test "init/1 raises when inbox_name is not provided" do
    assert_raise ArgumentError, ~r/required :inbox_name option not found/, fn ->
      Producer.init([])
    end
  end

  test "init/1 raises when dead_letter_name is not provided" do
    assert_raise ArgumentError, ~r/required :dead_letter_name option not found/, fn ->
      Producer.init(inbox_name: :foo)
    end
  end
end
