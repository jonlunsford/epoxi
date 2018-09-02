defmodule Epoxi.Queues.SupervisorTest do
  use ExUnit.Case

  describe "count_children" do
    test "it returns a map about it's children" do
      assert %{active: _, specs: _, supervisors: _, workers: _} = Epoxi.Queues.Supervisor.count_children()
    end
  end

  describe "which_children" do
    test "it returns a list about it's children" do
      Epoxi.Queues.Supervisor.start_child({Epoxi.Queues.Inbox, :queue.new})

      assert {Epoxi.Queues.Retries, _pid, :worker, [Epoxi.Queues.Retries]} = List.first(Epoxi.Queues.Supervisor.which_children())
    end
  end

  describe "available_for_poll" do
    # TODO: refactor to actually look for something useful
    test "it returns the single Inbox queue" do
      Epoxi.Queues.Supervisor.start_child({Epoxi.Queues.Inbox, :queue.new})
      Epoxi.Queues.Supervisor.start_child({Epoxi.Queues.Retries, :queue.new})

      assert is_pid(Epoxi.Queues.Supervisor.available_for_poll())
    end
  end
end
