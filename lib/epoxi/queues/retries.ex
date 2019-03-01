defmodule Epoxi.Queues.Retries do
  require Logger
  @moduledoc """
  Acts as a queue to hold failures

  TODO: Make eventually persistent
  """

  @max_retry_delay 1024
  @max_retry_count 17

  use GenServer

  def start_link(queue) do
    GenServer.start_link(__MODULE__, queue)
  end

  ## Public API

  def enqueue(pid, payload) do
    GenServer.cast(pid, {:enqueue, payload})
  end

  def dequeue(pid) do
    GenServer.call(pid, :dequeue)
  end

  def queue_size(pid) do
    GenServer.call(pid, :queue_size)
  end

  def retry(pid) do
    GenServer.call(pid, :retry)
  end

  ## Callbacks

  def init(queue) do
    {:ok, queue}
  end

  def handle_cast({:enqueue, payload}, queue) do
    log("Enqueueing retry: #{inspect(payload)}")
    schedule_retry(payload)
    {:noreply, :queue.in(payload, queue)}
  end

  def handle_call(:dequeue, _from, queue) do
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        {:reply, [item], new_queue}
      {:empty, cur_queue} ->
        {:reply, {:ok, :empty}, cur_queue}
    end
  end

  def handle_info(:retry, queue) do
    inbox = Epoxi.Queues.Supervisor.available_inbox()

    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        log("Sending Retry: #{inspect(item)}")
        Epoxi.Queues.Inbox.enqueue(inbox, item)
        {:reply, [item], new_queue}
      {:empty, cur_queue} ->
        {:reply, {:ok, :empty}, cur_queue}
    end
  end

  def handle_call(:queue_size, _from, queue) do
    {:reply, :queue.len(queue), queue}
  end

  defp schedule_retry(payload, initial_delay \\ 10) do
    next_send_time = :erlang.round(initial_delay * :math.pow(2, payload.failures)) * 100
    log("Next send attempt: #{next_send_time}")
    Process.send_after(self(), :retry, next_send_time)
  end

  defp log(message, color \\ :magenta) do
    Logger.debug(message, ansi_color: color)
  end
end
