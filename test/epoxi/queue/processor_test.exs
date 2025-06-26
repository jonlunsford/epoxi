defmodule Epoxi.Queue.ProcessorTest do
  use ExUnit.Case, async: true

  setup do
    processor_name = :"test_processor_#{:erlang.unique_integer([:positive])}"

    producer_options = [
      module:
        {Application.get_env(:epoxi, :producer_module),
         Application.get_env(:epoxi, :producer_options)},
      concurrency: 1
    ]

    {:ok, _pid} =
      start_supervised(
        {Epoxi.Queue.Processor, [name: processor_name, producer_options: producer_options]}
      )

    on_exit(fn ->
      :dets.close(String.to_charlist("#{processor_name}_inbox.dets"))
      :dets.close(String.to_charlist("#{processor_name}_dlq.dets"))
      File.rm!("priv/queues/#{processor_name}_inbox.dets")
      File.rm!("priv/queues/#{processor_name}_dlq.dets")
    end)

    {:ok, %{processor_name: processor_name}}
  end

  test "successful messages", %{processor_name: processor_name} do
    # message format:
    # {:ack, ^ref, successful_messages, failure_messages}

    [email] = Epoxi.Test.Helpers.generate_emails(1)

    ref = Broadway.test_message(processor_name, email)

    assert_receive({:ack, ^ref, [%Broadway.Message{}], []})
  end

  test "failed messages", %{processor_name: processor_name} do
    [email] =
      Epoxi.Test.Helpers.generate_emails(1, fn _index -> %{to: ["test+422@localhost"]} end)

    ref = Broadway.test_message(processor_name, email)

    assert_receive({:ack, ^ref, [], [%Broadway.Message{}]})
  end
end
