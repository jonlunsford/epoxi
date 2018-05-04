defmodule Epoxi.Queues.InboxSupervisor do
  use Supervisor

  alias Epoxi.Queues.Inbox

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

  @doc """
  TODO: Make this look for available children
  """
  def available_for_poll() do
    {Epoxi.Queues.Inbox, pid, :worker, [Epoxi.Queues.Inbox]} = List.first(which_children())
    pid
  end

  def terminate_child(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  # Callbacks

  def init(_args) do
    children = [
      {Inbox, :queue.new}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
