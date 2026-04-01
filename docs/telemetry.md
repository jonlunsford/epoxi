# Telemetry

Epoxi emits telemetry events throughout the email processing lifecycle using Erlang's `:telemetry` library. These events can be consumed by any compatible reporter (StatsD, Prometheus, console, etc.) to build dashboards, alerts, and operational visibility.

## Telemetry Supervisor

`Epoxi.Telemetry` is a supervisor started as part of the application tree. It runs a `:telemetry_poller` that collects VM metrics every 10 seconds.

```elixir
# In lib/epoxi/telemetry.ex
children = [
  {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
]
```

## Metric Definitions

`Epoxi.Telemetry.metrics/0` returns the full list of defined metrics. These are `Telemetry.Metrics` structs suitable for any compatible reporter.

### Endpoint Metrics

| Metric | Type | Unit | Description |
|---|---|---|---|
| `epoxi.endpoint.stop.duration` | summary | ms | HTTP request duration |

Emitted by `Plug.Telemetry` on every request to the HTTP API.

### Pipeline Metrics (Broadway)

| Metric | Type | Unit | Description |
|---|---|---|---|
| `broadway.processor.stop.system_time` | summary | ms | Time spent in message processors |
| `broadway.batcher.stop.duration` | summary | ms | Time spent accumulating batches |
| `broadway.batch_processor.stop.duration` | summary | ms | Time spent processing batches (SMTP delivery) |

These are emitted automatically by Broadway for every pipeline.

### Queue Metrics

| Metric | Type | Description |
|---|---|---|
| `epoxi.queue.batch_processed.successful` | summary | Count of successfully delivered emails per batch |
| `epoxi.queue.batch_processed.failed` | summary | Count of failed emails per batch |
| `epoxi.queue.sync.count` | summary | Number of messages synced to DETS |

### VM Metrics

| Metric | Type | Unit | Description |
|---|---|---|---|
| `vm.memory.total` | summary | KB | Total BEAM memory usage |
| `vm.total_run_queue_lengths.total` | summary | -- | Total scheduler run queue length |
| `vm.total_run_queue_lengths.cpu` | summary | -- | CPU scheduler run queue length |
| `vm.total_run_queue_lengths.io` | summary | -- | IO scheduler run queue length |

Collected by `:telemetry_poller` every 10 seconds.

## Custom Events

Beyond the metrics defined in `Epoxi.Telemetry.metrics/0`, the following events are emitted directly via `:telemetry.execute/3` throughout the codebase:

### Queue Events

**`[:epoxi, :queue, :batch_processed]`**

Emitted by `Epoxi.Queue.Producer.ack/3` after each batch is acknowledged.

```elixir
# Measurements
%{successful: 10, failed: 2}

# Metadata
%{inbox_ref: :my_pipeline_inbox, dead_letter_ref: :my_pipeline_dlq}
```

**`[:epoxi, :queue, :sync]`**

Emitted on every ETS-to-DETS sync (periodic and manual).

```elixir
# Measurements
%{count: 42}   # number of messages in queue at sync time

# Metadata
%{queue: :my_queue}
```

**`[:epoxi, :queue, :destroyed]`**

Emitted when a queue is destroyed after draining.

```elixir
# Measurements
%{}

# Metadata
%{queue: :my_queue}
```

**`[:epoxi, :queue, :pipeline_cleanup]`**

Emitted when empty queues are cleaned up during pipeline drain.

```elixir
# Measurements
%{queues_cleaned: 2}

# Metadata
%{pipeline: :my_pipeline, inbox: :my_pipeline_inbox, dlq: :my_pipeline_dlq}
```

**`[:epoxi, :queue, :fetch_messages]`** (span)

Wraps each demand-driven fetch from the inbox queue. Emitted as a telemetry span with `start` and `stop` events.

```elixir
# Metadata (start)
%{inbox_ref: :my_pipeline_inbox, demand: 10}

# Metadata (stop, adds)
%{messages: [...]}
```

### Routing Events

**`[:epoxi, :router, :route, :count]`**

Emitted on every inter-node call or cast.

```elixir
# Measurements
%{count: 1}

# Metadata
%{source_node: #PID<0.123.0>, target_node: :"epoxi@10.0.0.2", result: {:ok, ...}}
```

**`[:epoxi, :router, :route, :latency]`**

Emitted alongside `:count` with the duration of the ERPC call.

```elixir
# Measurements
%{duration: 4200}   # native time units

# Metadata
%{source_node: #PID<0.123.0>, target_node: :"epoxi@10.0.0.2"}
```

## Attaching a Reporter

To consume these metrics in production, add a reporter to the telemetry supervisor. For example, with `telemetry_metrics_statsd`:

```elixir
# In mix.exs deps
{:telemetry_metrics_statsd, "~> 0.7"}
```

```elixir
# In lib/epoxi/telemetry.ex, add to children list:
children = [
  {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
  {TelemetryMetricsStatsd, metrics: metrics(), host: "statsd.internal", port: 8125}
]
```

For console output during development:

```elixir
children = [
  {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
  {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
]
```

## Attaching Custom Handlers

For ad-hoc event handling outside the metrics system, attach handlers directly:

```elixir
:telemetry.attach(
  "log-batch-results",
  [:epoxi, :queue, :batch_processed],
  fn _event, measurements, metadata, _config ->
    Logger.info(
      "Batch processed: #{measurements.successful} ok, #{measurements.failed} failed " <>
      "on queue #{metadata.inbox_ref}"
    )
  end,
  nil
)
```

## Pipeline Admin Endpoints

The HTTP admin API exposes telemetry-adjacent operational data:

| Endpoint | Data |
|---|---|
| `GET /admin/pipelines` | Cluster-wide pipeline stats, health summary, routing key distribution, node load |
| `GET /admin/pipelines/health` | Per-pipeline health check results |
| `GET /admin/pipelines/:routing_key` | Health for pipelines serving a specific routing key |

See [HTTP API](http-api.md#pipeline-administration) for details.
