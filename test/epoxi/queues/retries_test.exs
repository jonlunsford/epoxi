defmodule Epoxi.Queues.RetriesTest do
  use ExUnit.Case

  alias Epoxi.Queues.Retries

  setup do
    inbox = start_supervised!({Retries, :queue.new})

    %{inbox: inbox}
  end

  describe "enqueue" do
    test "it enqueues events", %{inbox: inbox} do
      assert {:ok, "enqueued"} = Retries.enqueue(inbox, %{message: "deliver", payload: %{email: "..."}})
    end
  end

  describe "dequeue" do
    test "it returns an item from the queue", %{inbox: inbox} do
      payload = %{message: "out", payload: %{}}
      Retries.enqueue(inbox, payload)

      assert Retries.dequeue(inbox) == [payload]
    end

    test "it returns items FIFO", %{inbox: inbox} do
      payload_1 = %{message: "first", payload: %{}}
      payload_2 = %{message: "second", payload: %{}}

      Retries.enqueue(inbox, payload_1)
      Retries.enqueue(inbox, payload_2)

      assert Retries.dequeue(inbox) == [payload_1]
    end

    test "it replies with an empty message", %{inbox: inbox} do
      assert {:ok, :empty} = Retries.dequeue(inbox)
    end
  end

  describe "queue_size" do
    test "it returns the total queue size", %{inbox: inbox} do
      payload_1 = %{message: "first", payload: %{}}
      payload_2 = %{message: "second", payload: %{}}

      Retries.enqueue(inbox, payload_1)
      Retries.enqueue(inbox, payload_2)

      assert Retries.queue_size(inbox) == 2
    end
  end
end
