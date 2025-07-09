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

  describe "empty?/1" do
    test "returns true when queue is empty", %{queue: queue} do
      assert Epoxi.Queue.empty?(queue) == true
    end

    test "returns false when queue has messages", %{queue: queue} do
      Epoxi.Queue.enqueue(queue, "test message")
      assert Epoxi.Queue.empty?(queue) == false
    end
  end

  describe "exists?/1" do
    test "returns true when queue exists", %{queue: queue} do
      assert Epoxi.Queue.exists?(queue) == true
    end

    test "returns false for non-existent queue" do
      non_existent_queue = :non_existent_queue_123
      assert Epoxi.Queue.exists?(non_existent_queue) == false
    end
  end

  describe "destroy/1" do
    test "destroys empty queue successfully", %{queue: queue} do
      # Ensure queue is empty
      assert Epoxi.Queue.empty?(queue) == true

      # Destroy the queue
      assert :ok = Epoxi.Queue.destroy(queue)

      # Verify queue no longer exists
      assert Epoxi.Queue.exists?(queue) == false
    end

    test "fails to destroy non-empty queue", %{queue: queue} do
      # Add a message to the queue
      Epoxi.Queue.enqueue(queue, "test message")

      # Attempt to destroy should fail
      assert {:error, {:queue_not_empty, 1}} = Epoxi.Queue.destroy(queue)

      # Verify queue still exists
      assert Epoxi.Queue.exists?(queue) == true
    end

    test "handles destroy of non-existent queue gracefully" do
      non_existent_queue = :non_existent_queue_123

      # Should return error for non-existent queue
      assert {:error, _reason} = Epoxi.Queue.destroy(non_existent_queue)
    end
  end
end
