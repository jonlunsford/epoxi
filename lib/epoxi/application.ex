defmodule Epoxi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Epoxi.Queues.InboxSupervisor,
      {Epoxi.Queues.Poller, %{adapter_module: Epoxi.Queues.InternalAdapter}},
      Epoxi.Mail.Decoder,
      Epoxi.Mail.Dispatcher,
      Epoxi.Mail.SenderSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Epoxi.Supervisors.Main]
    Supervisor.start_link(children, opts)
  end
end
