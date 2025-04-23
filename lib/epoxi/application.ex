defmodule Epoxi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Epoxi.Telemetry, []},
      {OffBroadwayMemory.Buffer, name: :inbox},
      {Epoxi.Queue.Processor, [concurrency: 10]},
      {Bandit, Application.get_env(:epoxi, :endpoint_options)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
