defmodule Epoxi.Consumers.Supervisor do
  use ConsumerSupervisor

  alias Epoxi.Producers
  alias Epoxi.Consumers

  def start_link(_args) do
    ConsumerSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Consumers.Mail, [], restart: :transient)
    ]

    {:ok, children, strategy: :one_for_one, subscribe_to: [{Producers.Mail, max_demand: 50}]}
  end
end
