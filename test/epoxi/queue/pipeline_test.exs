defmodule Epoxi.Queue.PipelineTest do
  use ExUnit.Case, async: true

  setup do
    pipeline_name = :"test_pipeline_#{:erlang.unique_integer([:positive])}"

    opts = [
      name: pipeline_name,
      batching: [
        size: 10,
        timeout: 5_000,
        concurrency: 2
      ],
      rate_limiting: [
        allowed_messages: 10,
        interval: 1000
      ]
    ]

    {:ok, _pid} =
      start_supervised({Epoxi.Queue.Pipeline, opts})

    on_exit(fn ->
      :dets.close(String.to_charlist("#{pipeline_name}_inbox.dets"))
      :dets.close(String.to_charlist("#{pipeline_name}_dlq.dets"))
      File.rm!("priv/queues/#{pipeline_name}_inbox.dets")
      File.rm!("priv/queues/#{pipeline_name}_dlq.dets")
    end)

    {:ok, %{pipeline_name: pipeline_name}}
  end

  test "successful messages", %{pipeline_name: pipeline_name} do
    # message format:
    # {:ack, ^ref, successful_messages, failure_messages}

    [email] = Epoxi.Test.Helpers.generate_emails(1)

    ref = Broadway.test_message(pipeline_name, email)

    assert_receive({:ack, ^ref, [%Broadway.Message{}], []})
  end

  test "failed messages", %{pipeline_name: pipeline_name} do
    [email] =
      Epoxi.Test.Helpers.generate_emails(1, fn _index -> %{to: ["test+422@localhost"]} end)

    ref = Broadway.test_message(pipeline_name, email)

    assert_receive({:ack, ^ref, [], [%Broadway.Message{}]})
  end
end
