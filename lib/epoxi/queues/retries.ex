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
    GenServer.cast(pid, {:enqueue, payload})
  end

  def dequeue(pid) do
    GenServer.call(pid, :dequeue)
  end

  def queue_size(pid) do
    GenServer.call(pid, :queue_size)
  end

  def retry(pid) do
    GenServer.cast(pid, :retry)
  end

  ## Callbacks

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:enqueue, payload}, state) do
    log("Enqueueing retry: #{inspect(payload)}")
    {:noreply, [payload | state]}
  end

  def handle_cast(:retry, state) do
    inbox = Epoxi.Queues.Supervisor.available_inbox()

    case List.pop_at(state, -1) do
      {:ok, nil} ->
        {:noreply, state}
      {:ok, result} ->
        log("Sending Retry: #{inspect(result)}")
        Epoxi.Queues.Inbox.enqueue(inbox, result)
        {:noreply, state}
    end
  end

  def handle_call(:dequeue, _from, state) do
    {reply, new_state} = List.pop_at(state, -1)
    {:reply, {:ok, reply || :empty}, new_state}
  end

  def handle_call(:queue_size, _from, state) do
    {:reply, Enum.count(state), state}
  end

  defp log(message, color \\ :magenta) do
    Logger.debug(message, ansi_color: color)
  end
end
