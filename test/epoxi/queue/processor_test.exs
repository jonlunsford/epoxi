defmodule Epoxi.Queue.ProcessorTest do
  use ExUnit.Case, async: true

  alias Epoxi.Queue.Processor

  test "successful messages" do
    # message format:
    # {:ack, ^ref, successful_messages, failure_messages}

    [email] = Epoxi.Test.Helpers.generate_emails(1)

    ref = Broadway.test_message(Processor, email)

    assert_receive({:ack, ^ref, [%Broadway.Message{}], []})
  end

  test "failed messages" do
    [email] =
      Epoxi.Test.Helpers.generate_emails(1, fn _index -> %{to: ["test+422@localhost"]} end)

    ref = Broadway.test_message(Processor, email)

    assert_receive({:ack, ^ref, [], [%Broadway.Message{}]})
  end
end
