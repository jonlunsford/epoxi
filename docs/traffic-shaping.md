# Traffic Shaping

Epoxi automatically shapes outbound traffic based on the destination mail provider. When emails are batched for delivery, the system performs an MX record lookup for each recipient domain, identifies the provider from the MX hostname, and applies a provider-specific `PipelinePolicy` that controls connection concurrency, batch sizes, and rate limits.

## How It Works

1. `Epoxi.Email.Batch.from_emails/2` groups emails by routing key (MX host + sending IP).
2. For each group, `Epoxi.ProviderPolicy.for_mx_host/1` matches the MX hostname against known providers.
3. The matched policy is attached to the batch and used to configure the Broadway pipeline that processes it.

Provider detection is based on substring matching against the MX hostname:

| MX hostname contains | Provider |
|---|---|
| `gmail` or `google` | `:google` |
| `yahoo` | `:yahoo` |
| `aol` | `:aol` |
| `outlook` or `hotmail` | `:outlook` |
| `icloud` | `:icloud` |
| _(anything else)_ | `:default` |

## Provider Policies

Each provider has a tuned `Epoxi.Queue.PipelinePolicy` that controls pipeline behavior:

| Parameter | Google | Yahoo | AOL | Outlook | iCloud | Default |
|---|---|---|---|---|---|---|
| `max_connections` | 10 | 8 | 5 | 12 | 3 | 5 |
| `max_retries` | 5 | 3 | 3 | 4 | 2 | 3 |
| `batch_size` | 10 | 5 | 5 | 8 | 3 | 5 |
| `batch_timeout` | 5,000 ms | 3,000 ms | 3,000 ms | 4,000 ms | 2,000 ms | 5,000 ms |
| `allowed_messages` | 100 | 50 | 30 | 80 | 20 | 50 |
| `message_interval` | 60 s | 120 s | 180 s | 90 s | 300 s | 5 s |

### What Each Parameter Controls

- **`max_connections`** -- Number of concurrent batcher workers sending to the provider. Maps directly to Broadway batcher concurrency for the `:pending` batcher.
- **`max_retries`** -- Maximum delivery attempts before an email is sent to the dead letter queue. Passed to the producer.
- **`batch_size`** -- Maximum emails per SMTP batch. The `SmtpClient` opens a single persistent connection and delivers this many emails over it before closing.
- **`batch_timeout`** -- Maximum time (ms) to wait for a batch to fill before sending a partial batch. Lower values reduce latency; higher values improve connection efficiency.
- **`allowed_messages`** -- Rate limit: maximum messages allowed within `message_interval`. This is tracked per pipeline.
- **`message_interval`** -- The time window (ms) for the `allowed_messages` rate limit.

### Retry Batcher Derivation

The retry batcher settings are automatically derived from the provider policy to use more conservative throughput:

| Retry Parameter | Formula | Purpose |
|---|---|---|
| Batch size | `max(5, batch_size / 4)` | Smaller batches for retries |
| Batch timeout | `max(30_000, batch_timeout * 2)` | Longer accumulation window |
| Concurrency | `max(2, max_connections / 5)` | Fewer concurrent retry workers |

## MX Lookups and Caching

`Epoxi.DNS.MxLookup` resolves MX records using Erlang's `:inet_res.lookup/3` and caches results in `:persistent_term`. The first MX record (lowest priority number) is used to determine the provider and SMTP relay host.

```elixir
Epoxi.DNS.MxLookup.lookup("gmail.com")
# => [{5, ~c"gmail-smtp-in.l.google.com"}, {10, ~c"alt1.gmail-smtp-in.l.google.com"}, ...]
```

The cache currently has no TTL -- entries persist for the lifetime of the node. In high-volume production environments, consider restarting nodes periodically or clearing `:persistent_term` entries if DNS changes need to propagate quickly.

## Routing Keys

Each unique combination of MX host and sending IP produces a routing key via `Epoxi.Email.RoutingKey.generate/2`:

```elixir
Epoxi.Email.RoutingKey.generate("gmail-smtp-in.l.google.com", "10.0.0.1")
# => "gmail_smtp_in_l_google_com_10_0_0_1"
```

Domain names are sanitized (non-alphanumeric characters replaced with `_`) and IPs have dots replaced with `_`. Each routing key gets its own Broadway pipeline, ensuring traffic to different providers (and from different IPs) is isolated.

## Example: Full Flow

A batch of emails to `user@gmail.com` from IP `10.0.0.1`:

1. MX lookup for `gmail.com` returns `gmail-smtp-in.l.google.com`.
2. Provider detection matches `"google"` in the hostname -- selects the `:google` policy.
3. Routing key: `gmail_smtp_in_l_google_com_10_0_0_1`.
4. A Broadway pipeline is started with the Google policy: 10 concurrent connections, batches of 10, 5-second batch timeout.
5. Emails are enqueued to the pipeline's inbox queue.
6. The pending batcher delivers batches of up to 10 emails over persistent SMTP connections to `gmail-smtp-in.l.google.com`.
7. Failed deliveries enter the retry batcher with reduced concurrency (2 workers, batches of 5, 30-second timeout).

## Customization

Provider policies are currently defined as hardcoded functions in `Epoxi.ProviderPolicy`. To add a new provider or adjust limits, modify the `determine_provider/1` and `get_policy/1` functions:

```elixir
# In lib/epoxi/provider_policy.ex

# Add detection
defp determine_provider(mx_host) do
  cond do
    String.contains?(mx_host, "protonmail") -> :protonmail
    # ... existing providers ...
  end
end

# Add policy
defp get_policy(:protonmail) do
  PipelinePolicy.new(
    name: :protonmail,
    max_connections: 5,
    max_retries: 3,
    batch_size: 5,
    batch_timeout: 5_000,
    allowed_messages: 30,
    message_interval: 120_000
  )
end
```

The default pipeline started at application boot (see [Configuration](configuration.md#pipeline-policy-defaults)) is separate from provider pipelines. It handles emails before they are routed through the provider-aware batching system.
