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

  describe "handle_message/3" do
    test "it places messages in the :domain batcher when :pending" do
      [email] = Epoxi.Test.Helpers.generate_emails(1)

      message = Message.new(%{email: email, status: :pending})
      broadway_message = Processor.transform(message, [])
      result = Processor.handle_message(:default, broadway_message, %{})

      assert %Broadway.Message{batcher: :domain} = result
    end
  end
end
