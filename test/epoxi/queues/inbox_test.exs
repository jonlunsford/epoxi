defmodule Epoxi.Queues.InboxTest do
  use ExUnit.Case

  alias Epoxi.Queues.Inbox

  setup do
    inbox = start_supervised!({Inbox, :queue.new})

    %{inbox: inbox}
  end

  describe "enqueue" do
    test "it enqueues events", %{inbox: inbox} do
      assert {:ok, "enqueued"} = Inbox.enqueue(inbox, %{message: "deliver", payload: %{email: "..."}})
    end
  end

  describe "dequeue" do
    test "it returns an item from the queue", %{inbox: inbox} do
      payload = %{message: "out", payload: %{}}
      Inbox.enqueue(inbox, payload)

      assert Inbox.dequeue(inbox) == [payload]
    end

    test "it returns items FIFO", %{inbox: inbox} do
      payload_1 = %{message: "first", payload: %{}}
      payload_2 = %{message: "second", payload: %{}}

      Inbox.enqueue(inbox, payload_1)
      Inbox.enqueue(inbox, payload_2)

      assert Inbox.dequeue(inbox) == [payload_1]
    end

    test "it replies with an empty message", %{inbox: inbox} do
      assert {:ok, :empty} = Inbox.dequeue(inbox)
    end
  end

  describe "drain" do
    test "it empties the whole queue in one call", %{inbox: inbox} do
      payload_1 = %{message: "first", payload: %{}}
      payload_2 = %{message: "second", payload: %{}}

      Inbox.enqueue(inbox, payload_1)
      Inbox.enqueue(inbox, payload_2)

      assert Inbox.drain(inbox) == [payload_1, payload_2]
    end

    test "it returns a single item", %{inbox: inbox} do
      payload_1 = %{message: "second", payload: %{}}

      Inbox.enqueue(inbox, payload_1)

      assert Inbox.drain(inbox) == [payload_1]
    end
  end

  describe "queue_size" do
    test "it returns the total queue size", %{inbox: inbox} do
      payload_1 = %{message: "first", payload: %{}}
      payload_2 = %{message: "second", payload: %{}}

      Inbox.enqueue(inbox, payload_1)
      Inbox.enqueue(inbox, payload_2)

      assert Inbox.queue_size(inbox) == 2
    end
  end
end
