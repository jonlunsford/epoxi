defmodule Epoxi.Queue.ProcessorTest do
  use ExUnit.Case, async: true

  alias Epoxi.{Context, Queue.Processor, Queue.Message}

  setup do
    context = Context.new()

    {:ok, context: context}
  end

  test "message", %{context: context} do
    # message format:
    # {:ack, ^ref, successful_messages, failure_messages}

    [email] = Epoxi.Test.Helpers.generate_emails(1)

    message = Message.new(%{email: email, context: context})

    ref = Broadway.test_message(Processor, message)

    assert_receive({:ack, ^ref, [%Broadway.Message{}], []})
  end
end
