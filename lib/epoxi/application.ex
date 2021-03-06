defmodule Epoxi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Epoxi.Metrics.Statsd,
      Epoxi.Queues.Supervisor,
      Epoxi.Mail.Decoder,
      Epoxi.Mail.SenderSupervisor,
      Epoxi.Endpoint.HTTP
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Epoxi.Supervisors.Main]
    Supervisor.start_link(children, opts)
  end
end
