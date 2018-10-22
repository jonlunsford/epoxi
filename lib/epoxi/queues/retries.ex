defmodule Epoxi.Queues.Retries do
  require Logger
  @moduledoc """
  Acts as a queue to hold failures

  TODO: Make eventually persistent
  """

  use GenServer

  def start_link(queue) do
    GenServer.start_link(__MODULE__, queue)
  end

  ## Public API

  def enqueue(pid, payload) do
    GenServer.call(pid, {:enqueue, payload})
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

  def handle_call({:enqueue, payload}, _from, queue) do
    log("Enqueueing retry: #{inspect(payload)}")
    queue = :queue.in(payload, queue)
    {:reply, {:ok, "enqueued"}, queue}
  end

  def handle_call(:dequeue, _from, queue) do
    case :queue.out(queue) do
      {{:value, item}, new_queue} ->
        {:reply, [item], new_queue}
      {:empty, cur_queue} ->
        {:reply, {:ok, :empty}, cur_queue}
    end
  end

  def handle_call(:retry, _from, queue) do
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

  defp log(message, color \\ :magenta) do
    Logger.debug(message, ansi_color: color)
  end
end
