defmodule Epoxi.Telemetry do
  @moduledoc """
  This module is responsible for logging telemetry events for the Epoxi application.
  """
  use Supervisor
  import Telemetry.Metrics
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Endpoint Metrics
      summary("epoxi.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      # Pipeline Metrics
      summary("broadway.processor.stop.system_time",
        unit: {:native, :millisecond}
      ),
      summary("broadway.batcher.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("broadway.batch_processor.stop.duration",
        unit: {:native, :millisecond}
      )
      # VM Metrics
      # summary("vm.memory.total", unit: {:byte, :kilobyte}),
      # summary("vm.total_run_queue_lengths.total"),
      # summary("vm.total_run_queue_lengths.cpu"),
      # summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      {:process_info,
       name: :inbox,
       event: [:epoxi, :inbox, :process_info],
       keys: [:message_queue_length, :memory]}
    ]
  end
end
