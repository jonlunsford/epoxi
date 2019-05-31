defmodule Epoxi.Metrics.Statsd do
  import Telemetry.Metrics

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(_) do
    TelemetryMetricsStatsd.start_link(
      metrics: [
        distribution("epoxi.endpoint.stop.duration", unit: {:native, :millisecond}, buckets: [0, 100, 200, 300, 400, 500]),
        distribution("epoxi.endpoint.start.time", unit: {:native, :millisecond}, buckets: [0]),
        last_value("vm.memory.total"),
        last_value("vm.total_run_queue_lengths.total"),
        last_value("vm.total_run_queue_lengths.cpu"),
        last_value("vm.total_run_queue_lengths.io")
      ]
    )
  end
end
