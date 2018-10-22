defmodule Epoxi.Queues.Supervisor do
  @moduledoc """
  Supervisor for queues, to be used as a pool for delegating work and
  referencing currently running queues.

  TODO:
  - Allow args to dictate how many queues to boot with
  - Find available queues, indicated by them _not_ having a poller
  - Auto scale queues up and down based on queue max / min threshold (TBD)
  """
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  # Public API

  def start_child(pid \\ __MODULE__, {module, args}) do
    Supervisor.start_child(pid, {module, args})
  end

  def count_children() do
    Supervisor.count_children(__MODULE__)
  end

  def which_children() do
    Supervisor.which_children(__MODULE__)
  end

  def available_inbox() do
    # TODO: Select from dynamic queues rather that hard coded
    {Epoxi.Queues.Inbox, pid, :worker, [Epoxi.Queues.Inbox]} = List.last(which_children())
    pid
  end

  def available_retries() do
    {Epoxi.Queues.Retries, pid, :worker, [Epoxi.Queues.Retries]} = List.first(which_children())
    pid
  end

  def terminate_child(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  # Callbacks

  def init(_args) do
    children = [
      {Epoxi.Queues.Inbox, :queue.new},
      {Epoxi.Queues.Retries, :queue.new}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
