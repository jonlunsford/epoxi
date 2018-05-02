defmodule Epoxi.Queues.InboxSupervisorTest do
  use ExUnit.Case

  alias Epoxi.Queues.InboxSupervisor

  describe "start_child" do
    test "it adds children dynamically" do
      assert {:ok, _pid} = InboxSupervisor.start_child({Epoxi.Queues.Inbox, :queue.new})
    end
  end

  describe "count_children" do
    test "it returns a map about it's children" do
      InboxSupervisor.start_child({Epoxi.Queues.Inbox, :queue.new})
      InboxSupervisor.start_child({Epoxi.Queues.Inbox, :queue.new})

      assert %{active: _, specs: _, supervisors: _, workers: _} = InboxSupervisor.count_children()
    end
  end

  describe "which_children" do
    test "it returns a list about it's children" do
      InboxSupervisor.start_child({Epoxi.Queues.Inbox, :queue.new})

      assert [{:undefined, _pid, :worker, [Epoxi.Queues.Inbox]} | _] = InboxSupervisor.which_children()
    end
  end

  describe "terminate_child" do
    test "it terminates the specified child" do
      {:ok, pid} = InboxSupervisor.start_child({Epoxi.Queues.Inbox, :queue.new})

      assert :ok = InboxSupervisor.terminate_child(pid)
    end
  end
end
