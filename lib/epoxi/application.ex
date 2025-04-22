defmodule Epoxi.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {OffBroadwayMemory.Buffer, name: :inbox},
      {Epoxi.Queue.Processor, [concurrency: 10]},
      {Bandit,
       plug: Epoxi.Endpoint, scheme: :https, certfile: certfile_path(), keyfile: keyfile_path()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]
    Supervisor.start_link(children, opts)
  end

  defp certfile_path do
    :code.priv_dir(:epoxi) ++ "/cert.pem"
  end

  defp keyfile_path do
    :code.priv_dir(:epoxi) ++ "/key.pem"
  end
end
