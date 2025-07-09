defmodule Epoxi.Queue.PipelineTest do
  use ExUnit.Case, async: true

  setup do
    pipeline_name = :"test_pipeline_#{:erlang.unique_integer([:positive])}"

    policy = Epoxi.Queue.PipelinePolicy.new(name: pipeline_name)
    opts = Epoxi.Queue.Pipeline.build_policy_opts(policy)

    {:ok, _pid} =
      start_supervised({Epoxi.Queue.Pipeline, opts})

    on_exit(fn ->
      # Clean up any remaining DETS files if they still exist
      # (our queue cleanup may have already removed them)
      cleanup_queue_files("#{pipeline_name}_inbox")
      cleanup_queue_files("#{pipeline_name}_dlq")
    end)

    {:ok, %{pipeline_name: pipeline_name}}
  end

  test "successful messages", %{pipeline_name: pipeline_name} do
    # message format:
    # {:ack, ^ref, successful_messages, failure_messages}

    [email] = Epoxi.Test.Helpers.generate_emails(1)

    ref = Broadway.test_message(pipeline_name, email)

    assert_receive({:ack, ^ref, [%Broadway.Message{}], []}, 3000)
  end

  test "failed messages", %{pipeline_name: pipeline_name} do
    [email] =
      Epoxi.Test.Helpers.generate_emails(1, fn _index -> %{to: ["test+422@localhost"]} end)

    ref = Broadway.test_message(pipeline_name, email)

    assert_receive({:ack, ^ref, [], [%Broadway.Message{}]}, 3000)
  end

  defp cleanup_queue_files(queue_name) do
    dets_path = "priv/queues/#{queue_name}.dets"

    case File.rm(dets_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> IO.puts("Failed to clean up #{dets_path}: #{reason}")
    end
  end
end
