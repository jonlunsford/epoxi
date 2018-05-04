defmodule Epoxi.Queues.Inbox do
  @moduledoc """
  Acts as a buffer queue, storing inbound messages to be delivered.

  Can be started with an existing queue, ideally we can recover from failure by
  supplying a queue recovered from disk.

  Expected payload:
    `%{message: "something", payload: any}`
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

  ## Callbacks

  def init(queue) do
    {:ok, queue}
  end

  def handle_call({:enqueue, payload}, _from, queue) do
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

  def handle_call(:queue_size, _from, queue) do
    {:reply, :queue.len(queue), queue}
  end
end
