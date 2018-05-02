defmodule Epoxi.Queues.InboxSupervisor do
  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # Public API

  def start_child(pid \\ __MODULE__, {module, args}) do
    DynamicSupervisor.start_child(pid, {module, args})
  end

  def count_children() do
    DynamicSupervisor.count_children(__MODULE__)
  end

  def which_children() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def terminate_child(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  # Callbacks

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
