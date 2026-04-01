# Configuration

Epoxi uses standard Elixir/Mix configuration with environment-specific files.

## Configuration Files

| File | Purpose |
|---|---|
| `config/config.exs` | Base configuration, imports environment config |
| `config/dev.exs` | Development defaults |
| `config/test.exs` | Test environment (uses dummy Broadway producer) |
| `config/prod.exs` | Production settings (HTTPS, real queues) |

## HTTP Endpoint

The HTTP endpoint is powered by Bandit and configured under the `:epoxi` application key:

```elixir
# config/dev.exs
config :epoxi,
  endpoint_options: [
    plug: Epoxi.Endpoint,
    scheme: :http,
    port: 4000
  ]
```

### Production (HTTPS)

```elixir
# config/prod.exs
config :epoxi,
  endpoint_options: [
    plug: Epoxi.Endpoint,
    scheme: :https,
    port: 443,
    certfile: "/path/to/cert.pem",
    keyfile: "/path/to/key.pem"
  ]
```

The `endpoint_options` keyword list is passed directly to Bandit. See the [Bandit documentation](https://hexdocs.pm/bandit/) for all available options including TLS cipher suites, HTTP/2 settings, and connection limits.

## Queue Producer

The queue producer module can be configured for different environments:

```elixir
config :epoxi,
  producer_module: Epoxi.Queue.Producer,
  producer_options: [
    inbox_name: :inbox,
    dead_letter_name: :dead
  ]
```

In test environments, `Broadway.DummyProducer` is used instead so tests don't depend on real queue infrastructure.

## DKIM Master Key

DKIM private keys are encrypted at rest using AES-256-GCM. The encryption master key must be configured for production:

```elixir
config :epoxi,
  dkim_master_key: "your-32-byte-secret-key-here-!!"
```

The master key must be exactly 32 bytes for AES-256, or it will be hashed with SHA-256 to derive a 32-byte key. If not configured, a deterministic default is used -- this is **not safe for production**.

Store this key securely using environment variables or a secrets manager:

```elixir
config :epoxi,
  dkim_master_key: System.fetch_env!("EPOXI_DKIM_MASTER_KEY")
```

## Queue Storage

Queues store their DETS files in a configurable directory:

```elixir
# Default: "priv/queues"
# Configure per-queue via start_link options:
Epoxi.Queue.start_link(name: :my_queue, table_dir: "/var/lib/epoxi/queues")
```

The default sync interval between ETS and DETS is 5,000 milliseconds. DETS also auto-saves every 60 seconds independently.

## Pipeline Policy Defaults

The default pipeline started at boot uses these settings:

| Parameter | Default | Description |
|---|---|---|
| `name` | `:default` | Pipeline identifier |
| `max_connections` | `10` | Concurrent SMTP batcher workers |
| `max_retries` | `5` | Max retry attempts before dead-letter |
| `batch_size` | `100` | Emails per batch |
| `batch_timeout` | `1_000` ms | Max wait time to fill a batch |
| `allowed_messages` | `1000` | Rate limit (messages per interval) |
| `message_interval` | `60_000` ms | Rate limit window |

These are configured in `Epoxi.Application.start_pipelines/0`. Dynamic pipelines created through the routing system inherit provider-specific policies (see [Traffic Shaping](traffic-shaping.md)).

## SMTP Client Defaults

The SMTP client defaults are defined in `Epoxi.SmtpConfig`:

| Parameter | Default | Description |
|---|---|---|
| `relay` | `"localhost"` | SMTP relay host |
| `hostname` | `"localhost"` | EHLO hostname |
| `port` | `2525` | SMTP port |
| `ssl` | `false` | Enable SSL |
| `tls` | `:if_available` | TLS mode |
| `auth` | `:if_available` | Authentication mode |
| `no_mx_lookups` | `false` | Skip MX record lookups |
| `retries` | `3` | Connection retry attempts |
| `on_transaction_error` | `:reset` | Error handling strategy |

These defaults are overridden per-delivery when the system does MX lookups to determine the correct relay for each domain.

## Erlang Distribution

For clustering, configure Erlang distribution in your release or `vm.args`:

```
-name epoxi@10.0.0.1
-setcookie epoxi_secret_cookie
```

Epoxi automatically detects cluster topology changes via `:net_kernel.monitor_nodes/2` and updates the `NodeRegistry` when nodes join or leave.

## Starting the Application

```bash
# Development
iex -S mix

# Production release
MIX_ENV=prod mix release
_build/prod/rel/epoxi/bin/epoxi start

# Foreground (no shell)
mix run --no-halt
```
