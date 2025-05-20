defmodule Epoxi.QueueTest do
  use ExUnit.Case, async: true
  alias Epoxi.Test.Helpers

  setup do
    queue_name = :"test_queue_#{:erlang.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({Epoxi.Queue, [name: queue_name]})

    on_exit(fn ->
      :dets.close(String.to_charlist("#{queue_name}.dets"))
      File.rm!("priv/queues/#{queue_name}.dets")
    end)

    %{queue: queue_name}
  end

  test "enqueue and dequeue operations", %{queue: queue} do
    # Test initial state
    assert Epoxi.Queue.length(queue) == 0
    assert Epoxi.Queue.peek(queue) == :empty

    # Test enqueue
    message = "test message"
    assert :ok = Epoxi.Queue.enqueue(queue, message)

    # Test length after enqueue
    assert Epoxi.Queue.length(queue) == 1

    # Test peek
    assert Epoxi.Queue.peek(queue) == {:ok, message}

    # Test dequeue
    assert Epoxi.Queue.dequeue(queue) == {:ok, message}
    assert Epoxi.Queue.length(queue) == 0
    assert Epoxi.Queue.dequeue(queue) == :empty
  end

  describe "enqueue_many/3" do
    test "it enqueues many messages async", %{queue: queue} do
      emails = Helpers.generate_emails(2)

      assert :ok = Epoxi.Queue.enqueue_many(queue, emails)
    end
  end
end
