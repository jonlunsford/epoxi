defmodule Epoxi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # {Task.Supervisor, name: Epoxi.RouterTasks},
      # {Task.Supervisor, name: Epoxi.DeliveryTasks},

      # Queue components
      {OffBroadwayMemory.Buffer, name: :inbox},

      # Processor components
      {Epoxi.Queue.Processor, [concurrency: 3]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
