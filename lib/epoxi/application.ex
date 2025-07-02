defmodule Epoxi.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    children = [
      {Epoxi.Telemetry, []},
      {Registry, keys: :unique, name: Epoxi.Queue.Registry},
      {Epoxi.PipelineSupervisor, []},
      {Epoxi.IpRegistry, []},
      {Task, fn -> start_pipelines() end},
      {Bandit, Application.get_env(:epoxi, :endpoint_options)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def start_pipelines() do
    Logger.info("Starting pipelines...")

    default_policy =
      Epoxi.Queue.PipelinePolicy.new(
        name: :default,
        max_connections: 10,
        max_retries: 5,
        batch_size: 100,
        batch_timeout: 1_000,
        allowed_messages: 1000,
        message_interval: 60_000
      )

    {:ok, _pid} = Epoxi.start_pipeline(default_policy)
  end
end
