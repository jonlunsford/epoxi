# Architecture

Epoxi is an Elixir/OTP Mail Transfer Agent (MTA) built for high-volume, fault-tolerant email delivery. It uses Broadway pipelines for concurrent processing, ETS/DETS hybrid queues for durability, and Erlang distribution for clustering.

## System Overview

```
                        ┌─────────────────────────────────────────────┐
                        │              Epoxi Application              │
                        │                                             │
  HTTP POST /messages   │  ┌───────────┐    ┌──────────────────────┐  │
  ─────────────────────►│  │  Endpoint  │───►│    Email.Router      │  │
                        │  │  (Bandit)  │    │  - Batch by MX host  │  │
                        │  └───────────┘    │  - Allocate IPs      │  │
                        │                   │  - Select nodes      │  │
                        │                   └──────────┬───────────┘  │
                        │                              │              │
                        │               ┌──────────────▼────────────┐ │
                        │               │    Queue.Pipeline          │ │
                        │               │    (Broadway)              │ │
                        │               │                            │ │
                        │               │  ┌────────┐  ┌──────────┐ │ │
                        │               │  │Producer│  │Processors│ │ │
                        │               │  │(Queue) │─►│(2 conc.) │ │ │
                        │               │  └────────┘  └────┬─────┘ │ │
                        │               │                   │       │ │
                        │               │         ┌─────────▼─────┐ │ │
                        │               │         │   Batchers    │ │ │
                        │               │         │ :pending      │ │ │
                        │               │         │ :retrying     │ │ │
                        │               │         └───────┬───────┘ │ │
                        │               └─────────────────┼─────────┘ │
                        │                                 │           │
                        │                    ┌────────────▼────────┐  │
                        │                    │    SmtpClient       │  │
                        │                    │  - Batch delivery   │  │
                        │                    │  - Persistent conn  │  │
                        │                    │  - DKIM signing     │  │
                        │                    └────────────┬────────┘  │
                        └─────────────────────────────────┼───────────┘
                                                          │
                                                          ▼
                                                    Remote SMTP
                                                    (gmail, yahoo, etc.)
```

## Supervision Tree

The application starts the following children under a `:one_for_one` supervisor:

| Child | Type | Purpose |
|---|---|---|
| `Epoxi.Telemetry` | Supervisor | Telemetry poller and metrics |
| `Registry` | Registry | Queue process discovery (`:unique` keys) |
| `Epoxi.DKIM.Registry` | GenServer | ETS-backed DKIM config storage |
| `Epoxi.Queue.PipelineSupervisor` | DynamicSupervisor | Manages Broadway pipeline processes |
| `Epoxi.NodeRegistry` | GenServer | Cluster state, IP pools, pipeline tracking |
| `Task` | Task | Starts the `:default` pipeline on boot |
| `Bandit` | HTTP Server | Serves the HTTP API |

Each Broadway pipeline spawns its own child processes:

```
PipelineSupervisor (DynamicSupervisor)
  └── Pipeline (Broadway)
        ├── Producer (GenStage, polls from Queue)
        ├── Queue :inbox (GenServer, ETS/DETS)
        ├── Queue :dlq (GenServer, ETS/DETS)
        ├── Processors (configurable concurrency)
        └── Batchers (:pending, :retrying)
```

## Message Flow

### 1. Injection

Messages enter the system via `POST /messages`. The JSON payload is decoded into `%Epoxi.Email{}` structs by `Epoxi.JSONDecoder`.

### 2. Routing

`Epoxi.Email.Router` orchestrates the routing:

1. **IP Allocation** -- `NodeRegistry.allocate_ips/3` assigns sending IPs from the specified pool to each email using configurable strategies (round-robin, weighted, random).
2. **Batching** -- `Email.Batch.from_emails/2` groups emails by routing key (MX host + assigned IP). Each batch gets a provider-aware `PipelinePolicy` (e.g., Google allows 10 connections, iCloud allows 3).
3. **Node Selection** -- `PipelineManager.select_optimal_node_for_pipeline/3` picks the best node using a `:least_pipelines` strategy.
4. **Pipeline Creation** -- A new Broadway pipeline is started on the selected node via `Epoxi.Node.route_call/4` (uses ERPC for remote nodes, direct `apply/3` for local).
5. **Enqueue** -- Emails are enqueued to the pipeline's inbox queue via `Epoxi.Node.route_cast/4`.

### 3. Processing

The Broadway pipeline processes emails through stages:

- **Producer** polls the inbox `Epoxi.Queue` at configurable intervals.
- **Processors** set each message's `batch_key` to the recipient domain and `batcher` to the email status (`:pending` or `:retrying`).
- **Pending Batcher** delivers batches via `SmtpClient.send_batch/2`, which opens a persistent SMTP connection and delivers all emails in the batch over it.
- **Retrying Batcher** checks `Email.time_to_retry?/1`; ready emails are delivered, not-ready emails are re-enqueued as failed.

### 4. Acknowledgment

The `Queue.Producer.ack/3` callback handles results:

- **Retrying emails** are re-enqueued to the inbox queue for another attempt.
- **Dead emails** (permanent failures, max retries exceeded) go to the dead letter queue.
- Telemetry events are emitted for both outcomes.

### 5. Retry Logic

Emails use exponential backoff with intervals of 5 minutes, 30 minutes, 2 hours, 4 hours, and 8 hours. After 5 retries, the email is marked as a permanent failure. Both temporary failures and network failures trigger retries; all other failure types are permanent.

## Direct Send Path

For applications that don't need queuing, Epoxi provides direct send functions:

```elixir
# Synchronous -- blocks until SMTP response
Epoxi.send(email)

# Asynchronous -- fires and forgets with optional callback
Epoxi.send_async(email, [], fn result -> handle(result) end)

# Bulk -- opens one connection, sends many
Epoxi.send_bulk([email1, email2, email3])
```

These bypass the queue/pipeline system entirely and use `gen_smtp_client` directly.

## Key Design Decisions

**Broadway for pipeline processing.** Broadway provides back-pressure, batching, fault tolerance, and graceful shutdown. Each pipeline has separate batchers for pending and retrying emails so retry logic doesn't block new deliveries.

**ETS/DETS hybrid queues.** ETS provides fast in-memory access with ordered-set tables for priority ordering. DETS provides disk persistence with periodic sync (default: every 5 seconds). On restart, DETS contents are loaded back into ETS.

**Provider-aware policies.** Each major email provider (Google, Yahoo, Outlook, iCloud, AOL) has tuned connection limits, batch sizes, and rate parameters. These are selected automatically based on MX record lookup results.

**ERPC for distribution.** Inter-node communication uses Erlang's ERPC module. `Epoxi.Node.route_call/4` and `route_cast/4` transparently handle local vs. remote dispatch -- local calls use `apply/3` directly, remote calls use `:erpc.call/4`.

**Encrypted DKIM keys.** Private keys are encrypted at rest using AES-256-GCM with per-tenant key derivation from a master key.
