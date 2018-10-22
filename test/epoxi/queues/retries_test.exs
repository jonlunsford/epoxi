defmodule Epoxi.Queues.RetriesTest do
  use ExUnit.Case

  alias Epoxi.Queues.Retries
  alias Epoxi.Test.Helpers

  setup do
    retries = start_supervised!({Retries, :queue.new})

    %{retries: retries}
  end

  describe "enqueue" do
    test "it enqueues events", %{retries: retries} do
      assert {:ok, "enqueued"} = Retries.enqueue(retries, %{message: "deliver", payload: %{email: "..."}})
    end
  end

  describe "dequeue" do
    test "it returns an item from the queue", %{retries: retries} do
      payload = %{message: "out", payload: %{}}
      Retries.enqueue(retries, payload)

      assert Retries.dequeue(retries) == [payload]
    end

    test "it returns items FIFO", %{retries: retries} do
      payload_1 = %{message: "first", payload: %{}}
      payload_2 = %{message: "second", payload: %{}}

      Retries.enqueue(retries, payload_1)
      Retries.enqueue(retries, payload_2)

      assert Retries.dequeue(retries) == [payload_1]
    end

    test "it replies with an empty message", %{retries: retries} do
      assert {:ok, :empty} = Retries.dequeue(retries)
    end
  end

  describe "queue_size" do
    test "it returns the total queue size", %{retries: retries} do
      payload_1 = %{message: "first", payload: %{}}
      payload_2 = %{message: "second", payload: %{}}

      Retries.enqueue(retries, payload_1)
      Retries.enqueue(retries, payload_2)

      assert Retries.queue_size(retries) == 2
    end
  end

  describe "retry" do
    test "it re-enqueues the failure to an available inbox", %{retries: retries} do
      failed_attempt = Helpers.test_json_string()

      Retries.enqueue(retries, failed_attempt)

      assert Retries.retry(retries) == [failed_attempt]
    end
  end
end
