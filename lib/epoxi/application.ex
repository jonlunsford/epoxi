defmodule Epoxi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Epoxi.Queues.InboxSupervisor,
      Epoxi.Producers.Mail,
      Epoxi.Consumers.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Epoxi.Supervisors.Main]
    Supervisor.start_link(children, opts)
  end
end
