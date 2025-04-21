defmodule Epoxi.Queue.ProcessorTest do
  use ExUnit.Case, async: true

  alias Epoxi.{Context, Queue.Processor}

  setup do
    context = Context.new()

    {:ok, context: context}
  end

  test "message" do
    # message format:
    # {:ack, ^ref, successful_messages, failure_messages}

    [email] = Epoxi.Test.Helpers.generate_emails(1)

    ref = Broadway.test_message(Processor, email)

    assert_receive({:ack, ^ref, [%Broadway.Message{}], []})
  end
end
