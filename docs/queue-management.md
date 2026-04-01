# Queue Management

Epoxi uses durable queues backed by a hybrid ETS/DETS storage engine, with Broadway pipelines for concurrent email processing.

## Durable Queues

Each queue (`Epoxi.Queue`) is a GenServer that maintains both an in-memory ETS ordered-set table and a persistent DETS table on disk. This gives fast access with crash recovery.

### Queue Lifecycle

1. On start, the DETS file is opened and its contents are loaded into a fresh ETS table.
2. Messages are inserted into ETS with composite keys `{priority, timestamp, id}` ensuring ordered dequeue across restarts.
3. Every `sync_interval` milliseconds (default: 5,000), the ETS table is synced to DETS.
4. On graceful shutdown, a final sync is performed and DETS is closed.

### Queue API

```elixir
# Start a named queue
{:ok, _pid} = Epoxi.Queue.start_link(name: :my_queue)

# Enqueue a single message (synchronous)
:ok = Epoxi.Queue.enqueue(:my_queue, email)

# Enqueue many messages (asynchronous, via cast)
:ok = Epoxi.Queue.enqueue_many(:my_queue, emails)

# Enqueue with priority (lower number = higher priority)
:ok = Epoxi.Queue.enqueue(:my_queue, urgent_email, priority: -1)

# Dequeue the next message
{:ok, email} = Epoxi.Queue.dequeue(:my_queue)
# or
:empty = Epoxi.Queue.dequeue(:my_queue)

# Peek without removing
{:ok, email} = Epoxi.Queue.peek(:my_queue)

# Queue inspection
Epoxi.Queue.length(:my_queue)    # => 42
Epoxi.Queue.empty?(:my_queue)    # => false
Epoxi.Queue.exists?(:my_queue)   # => true

# Force sync to disk
Epoxi.Queue.sync(:my_queue)

# Clear all messages
Epoxi.Queue.flush(:my_queue)

# Destroy queue (must be empty)
:ok = Epoxi.Queue.destroy(:my_queue)
```

### Queue Options

| Option | Default | Description |
|---|---|---|
| `:name` | required | Queue name (atom) |
| `:sync_interval` | `5_000` | Milliseconds between ETS-to-DETS syncs |
| `:table_dir` | `"priv/queues"` | Directory for DETS files |

### Storage Details

- **ETS table:** `:ordered_set`, `:protected`, `:named_table`. Keys are `{priority, timestamp, id}` tuples ensuring FIFO ordering within each priority level.
- **DETS file:** Located at `<table_dir>/<name>.dets`. Set type, auto-repair enabled, auto-save every 60 seconds.
- **Sync strategy:** On each sync, DETS is cleared and the full ETS table is written to DETS. This is a full snapshot, not incremental.

### Process Discovery

Queues register themselves via `Epoxi.Queue.Registry` (an Elixir `Registry` with `:unique` keys). This allows any process to locate a queue by name without knowing its PID.

## Broadway Pipelines

Each pipeline (`Epoxi.Queue.Pipeline`) is a Broadway topology that processes emails from a durable queue through to SMTP delivery.

### Pipeline Components

A pipeline consists of:

- **1 Producer** (`Epoxi.Queue.Producer`) -- polls the inbox queue on a configurable interval, transforms queue messages into `Broadway.Message` structs.
- **2 Processors** (default concurrency: 2) -- set the `batch_key` to the recipient domain and the `batcher` to the email's current status (`:pending` or `:retrying`).
- **N Pending Batchers** (concurrency = `max_connections`) -- deliver email batches via `SmtpClient.send_batch/2`.
- **M Retrying Batchers** (concurrency = `max(2, max_connections / 5)`) -- handle retry logic with reduced throughput.

### Pipeline Policies

Pipeline behavior is controlled by `Epoxi.Queue.PipelinePolicy`:

```elixir
policy = Epoxi.Queue.PipelinePolicy.new(
  name: :my_pipeline,
  max_connections: 10,
  max_retries: 5,
  batch_size: 50,
  batch_timeout: 5_000,
  allowed_messages: 100,
  message_interval: 60_000
)
```

| Field | Default | Effect |
|---|---|---|
| `name` | `:default` | Pipeline process name |
| `max_connections` | `10` | Concurrent pending batcher workers |
| `max_retries` | `5` | Max retry attempts (passed to producer) |
| `batch_size` | `10` | Emails per pending batch |
| `batch_timeout` | `5_000` ms | Max wait to fill a pending batch |
| `allowed_messages` | `100` | Rate limit per interval |
| `message_interval` | `60_000` ms | Rate limit window |

The retry batcher automatically derives conservative settings:
- **Retry batch size:** `max(5, batch_size / 4)`
- **Retry batch timeout:** `max(30_000, batch_timeout * 2)`
- **Retry concurrency:** `max(2, max_connections / 5)`

### Acknowledgment and Dead Letters

When Broadway finishes processing a batch, the `Producer.ack/3` callback routes results:

- **Successful messages** -- telemetry event emitted, no further action.
- **Failed with `:retrying` status** -- re-enqueued to the inbox queue for another attempt.
- **Failed with any other status** -- sent to the dead letter queue (DLQ).

### Queue Cleanup on Drain

When a pipeline drains (graceful shutdown), the producer:

1. Syncs both inbox and DLQ to disk.
2. If both queues are empty, spawns a cleanup task that destroys the queue files.
3. If queues have remaining messages, they're left on disk for recovery.

### Starting Pipelines

Pipelines are managed by `Epoxi.Queue.PipelineSupervisor` (a DynamicSupervisor):

```elixir
# From a policy
policy = Epoxi.Queue.PipelinePolicy.new(name: :gmail_pipeline, batch_size: 10)
opts = Epoxi.Queue.Pipeline.build_policy_opts(policy)
{:ok, pid} = Epoxi.start_pipeline(opts)

# From an email batch (used by the Router)
opts = Epoxi.Queue.Pipeline.build_policy_opts(batch)
{:ok, pid} = Epoxi.start_pipeline(opts)

# Idempotent -- returns {:ok, pid} if already running
{:ok, pid} = Epoxi.start_pipeline(opts)
```

The default pipeline (named `:default`) is started automatically when the application boots.
