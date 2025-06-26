defmodule Epoxi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Epoxi.Telemetry, []},
      {Registry, keys: :unique, name: Epoxi.Queue.Registry},
      {Epoxi.Queue.Processor, [name: :default]},
      # TODO: Optionall enable endpoint to be started per node.
      {Bandit, Application.get_env(:epoxi, :endpoint_options)}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end
end
