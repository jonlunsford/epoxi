defmodule Epoxi.Queue.Producer.CleanupTest do
  use ExUnit.Case, async: true

  alias Epoxi.Queue.Producer

  setup do
    # Create unique queue names for this test
    base_name = :"test_producer_#{:erlang.unique_integer([:positive])}"
    inbox_name = :"#{base_name}_inbox"
    dlq_name = :"#{base_name}_dlq"

    # Start the queues manually (not supervised) so we can destroy them
    {:ok, inbox_pid} = Epoxi.Queue.start_link([name: inbox_name])
    {:ok, dlq_pid} = Epoxi.Queue.start_link([name: dlq_name])

    # Create producer state
    state = %{
      inbox_ref: inbox_name,
      dead_letter_ref: dlq_name,
      ack_ref: base_name,
      demand: 0,
      poll_interval: 5000,
      max_retries: 5,
      transformer: {Producer, :transform, [base_name]}
    }

    on_exit(fn ->
      # Clean up any remaining processes and files
      if Process.alive?(inbox_pid), do: GenServer.stop(inbox_pid)
      if Process.alive?(dlq_pid), do: GenServer.stop(dlq_pid)
      cleanup_queue_files(inbox_name)
      cleanup_queue_files(dlq_name)
    end)

    %{state: state, inbox_name: inbox_name, dlq_name: dlq_name}
  end

  describe "prepare_for_draining/1 with queue cleanup" do
    test "triggers cleanup when both queues are empty", %{
      state: state,
      inbox_name: inbox_name,
      dlq_name: dlq_name
    } do
      # Ensure both queues are empty
      assert Epoxi.Queue.empty?(inbox_name) == true
      assert Epoxi.Queue.empty?(dlq_name) == true

      # Mock the persistent_term to avoid errors
      :persistent_term.put(state.ack_ref, %{
        inbox_ref: inbox_name,
        dead_letter_ref: dlq_name
      })

      # Call prepare_for_draining
      {:noreply, [], ^state} = Producer.prepare_for_draining(state)

      # Instead of sleep, we wait for the cleanup task to complete by polling
      # until the processes are actually terminated
      wait_for_queue_cleanup(inbox_name, dlq_name)
    end

    test "skips cleanup when inbox has messages", %{
      state: state,
      inbox_name: inbox_name,
      dlq_name: dlq_name
    } do
      # Add message to inbox
      Epoxi.Queue.enqueue(inbox_name, "test message")

      # Mock the persistent_term to avoid errors
      :persistent_term.put(state.ack_ref, %{
        inbox_ref: inbox_name,
        dead_letter_ref: dlq_name
      })

      # Call prepare_for_draining
      {:noreply, [], ^state} = Producer.prepare_for_draining(state)

      # Verify queues still exist (no cleanup should happen)
      # Give a small grace period then check
      Process.sleep(50)
      assert Epoxi.Queue.exists?(inbox_name) == true
      assert Epoxi.Queue.exists?(dlq_name) == true
    end

    test "skips cleanup when DLQ has messages", %{
      state: state,
      inbox_name: inbox_name,
      dlq_name: dlq_name
    } do
      # Add message to DLQ
      Epoxi.Queue.enqueue(dlq_name, "failed message")

      # Mock the persistent_term to avoid errors
      :persistent_term.put(state.ack_ref, %{
        inbox_ref: inbox_name,
        dead_letter_ref: dlq_name
      })

      # Call prepare_for_draining
      {:noreply, [], ^state} = Producer.prepare_for_draining(state)

      # Verify queues still exist (no cleanup should happen)
      # Give a small grace period then check
      Process.sleep(50)
      assert Epoxi.Queue.exists?(inbox_name) == true
      assert Epoxi.Queue.exists?(dlq_name) == true
    end
  end

  defp wait_for_queue_cleanup(inbox_name, dlq_name, attempts \\ 50) do
    if attempts <= 0 do
      flunk("Timed out waiting for queue cleanup")
    end

    case {Epoxi.Queue.exists?(inbox_name), Epoxi.Queue.exists?(dlq_name)} do
      {false, false} ->
        # Both queues are cleaned up
        :ok

      _ ->
        # Still exists, wait a bit and try again
        Process.sleep(10)
        wait_for_queue_cleanup(inbox_name, dlq_name, attempts - 1)
    end
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
