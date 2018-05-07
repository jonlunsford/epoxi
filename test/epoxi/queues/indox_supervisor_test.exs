defmodule Epoxi.Queues.InboxSupervisorTest do
  use ExUnit.Case

  alias Epoxi.Queues.InboxSupervisor

  describe "count_children" do
    test "it returns a map about it's children" do
      assert %{active: _, specs: _, supervisors: _, workers: _} = InboxSupervisor.count_children()
    end
  end

  describe "which_children" do
    test "it returns a list about it's children" do
      InboxSupervisor.start_child({Epoxi.Queues.Inbox, :queue.new})

      assert {Epoxi.Queues.Inbox, _pid, :worker, [Epoxi.Queues.Inbox]} = List.first(InboxSupervisor.which_children())
    end
  end
end
