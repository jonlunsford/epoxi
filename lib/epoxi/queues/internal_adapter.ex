defmodule Epoxi.Queues.InternalAdapter do
  alias Epoxi.Queues.Inbox

  def fetch_events(pid) do
    case Inbox.drain(pid) do
      [items] ->
        [items]
      {:ok, :empty} ->
        []
      _ ->
        []
    end
  end
end
