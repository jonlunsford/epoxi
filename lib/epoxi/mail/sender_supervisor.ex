defmodule Epoxi.Mail.SenderSupervisor do
  @moduledoc "Acts as a pool for mail producers, starts one Consumer.Mail process per event received"
  use ConsumerSupervisor

  def start_link(_args) do
    ConsumerSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Epoxi.Mail.Sender, [], restart: :transient)
    ]

    {:ok, children, strategy: :one_for_one, subscribe_to: [Epoxi.Mail.Dispatcher]}
  end
end
