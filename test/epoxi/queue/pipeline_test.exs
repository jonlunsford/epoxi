defmodule Epoxi.Queue.PipelineTest do
  use ExUnit.Case, async: true

  setup do
    pipeline_name = :"test_pipeline_#{:erlang.unique_integer([:positive])}"

    policy = Epoxi.Queue.PipelinePolicy.new(name: pipeline_name)
    opts = Epoxi.Queue.Pipeline.build_policy_opts(policy)

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
