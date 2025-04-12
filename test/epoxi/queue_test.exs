defmodule Epoxi.QueueTest do
  use ExUnit.Case, async: true

  alias Epoxi.{Email, Context, Queue}

  setup do
    context = Context.new()

    {:ok, context: context}
  end

  test "enqueue and process an email", %{context: context} do
    email = %Email{
      from: "sender@example.com",
      to: ["recipient@example.com"],
      subject: "Test",
      text: "Hello world"
    }

    {:ok, _id} = Queue.enqueue(email, context)
  end
end
