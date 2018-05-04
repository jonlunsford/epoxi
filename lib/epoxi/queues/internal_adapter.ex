defmodule Epoxi.Queues.InternalAdapter do
  alias Epoxi.Queues.Inbox

  def fetch_events(pid) do
    case Inbox.dequeue(pid) do
      [item] ->
        [item]
      {:ok, :empty} ->
        []
      _ ->
        []
    end
  end
end
