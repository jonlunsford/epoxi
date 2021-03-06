defmodule Epoxi.Queues.Inbox do
  @moduledoc """
  Streams all inbound payloads immediately

  Can be started with an existing queue, ideally we can recover from failure by
  supplying a queue recovered from disk.

  Expected payload:
    `some JSON string`
  """

  use GenStage

  def start_link(queue) do
    GenStage.start_link(__MODULE__, queue, name: __MODULE__)
  end

  ## Public API

  def enqueue(pid, payload) do
    GenStage.cast(pid, {:enqueue, payload})
  end

  def queue_size(pid) do
    GenStage.call(pid, :queue_size)
  end

  ## Callbacks

  def init(queue) do
    {:producer, queue}
  end

  def handle_cast({:enqueue, payload}, state) when is_list(payload) do
    {:noreply, payload, state}
  end

  def handle_cast({:enqueue, payload}, state), do: {:noreply, [payload], state}

  def handle_call(:queue_size, _from, state) do
    {:reply, Enum.count(state), state}
  end

  def handle_demand(_, state), do: {:noreply, [], state}
end
