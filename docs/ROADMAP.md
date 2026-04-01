# Epoxi Roadmap

Epoxi is an Elixir/OTP-based MTA/MDA targeting feature parity with industry-standard
production mail transfer agents. This document tracks completed work and remaining items,
ordered by priority for production readiness.

---

## Completed Features

### Core Email Processing
- **Email struct** -- Rich struct with retry tracking, exponential backoff, delivery log, status lifecycle (`pending -> retrying -> delivered | permanent_failure`)
- **Outbound SMTP delivery** -- Blocking, async, and bulk/batch delivery via `gen_smtp`
- **MIME rendering** -- Multipart (text/plain, text/html, multipart/mixed, multipart/alternative), custom headers, attachments struct
- **EEx template compiler** -- Dynamic email bodies via EEx templates

### Queue System
- **Durable queue** -- Hybrid ETS (in-memory) + DETS (on-disk) with configurable sync interval and crash recovery
- **Dead-letter queue (DLQ)** -- Failed messages routed to a separate DLQ after exhausting retries
- **Broadway pipeline** -- Per-domain batching with separate pending and retry batchers, configurable concurrency
- **Dynamic pipeline supervisor** -- Pipelines started on-demand per routing key (recipient domain)

### Email Authentication
- **DKIM signing (RSA only)** -- Outbound messages DKIM-signed using RSA-SHA256 via `mimemail`; keys stored AES-256-GCM encrypted per-tenant
- **DKIM key management** -- Full CRUD API (`POST/GET/PUT/DELETE /admin/dkim`) with ETS-backed registry and per-tenant key isolation

### DNS
- **MX record lookup** -- Outbound delivery resolves MX records via `:inet_res` with basic `persistent_term` caching

### Routing & IP Management
- **Domain-based routing** -- Emails batched and routed by recipient domain (routing key)
- **IP pool management** -- IPs grouped into named pools; allocation strategies: round-robin, weighted, least-used, random
- **Per-ISP provider policies** -- Delivery policies for Gmail, Yahoo, Outlook, iCloud, AOL, and default

### Distributed Cluster
- **Multi-node cluster** -- Erlang distribution with automatic node up/down tracking via `:net_kernel.monitor_nodes`
- **Distributed RPC** -- `Epoxi.Node.route_call/4` and `route_cast/4` transparently dispatch local or remote (ERPC)
- **Node registry** -- Cluster-wide registry tracking nodes, pipelines, IP pools, and IP weights
- **Pipeline health monitoring** -- `GET /admin/pipelines`, `/admin/pipelines/health`, `/admin/pipelines/:routing_key`

### HTTP API
- **Message injection** -- `POST /messages` accepts JSON email payloads, routes to optimal node/pipeline
- **Health check** -- `GET /ping`

### Multi-Tenancy
- **Tenant struct** -- Validated tenant model with domain ownership, status lifecycle (`active | inactive | suspended`)

### Observability
- **Telemetry events** -- Queue sync, batch processed, endpoint latency, Broadway processor/batcher metrics, VM metrics

---

## Production Roadmap

### Critical -- Blockers for Any Production Use

#### 1. Functional Inbound SMTP Server
`Epoxi.SmtpServer.handle_DATA/4` is a stub that returns `"1"` with no message queuing,
relay, or routing. The server accepts connections but silently discards mail.

Parse inbound DATA, validate recipients, enqueue messages to the internal queue.
Support configurable relay_hosts, max message size, max connections, per-connection
message limits.

#### 2. Inbound SMTP Authentication (AUTH PLAIN / LOGIN)
No AUTH mechanism implemented on the server side.

Implement SASL AUTH PLAIN and AUTH LOGIN on the inbound SMTP server. Support configurable
credential validation (static config, HTTP callback, or token-based). Require AUTH before
relaying for non-relay-host clients.

#### 3. TLS on Inbound SMTP (STARTTLS + Implicit TLS)
`handle_STARTTLS/1` is a no-op pass-through. No certificate loading or TLS handshake.

Load TLS certificate/key pair, negotiate STARTTLS on port 587, optionally support implicit
TLS (SMTPS) on port 465. Support configurable TLS required vs optional.

#### 4. Structured Delivery Logging
Delivery status is stored in `Email.log` (an in-memory list) and emitted via `Logger`.
No persistent delivery records, no queryable audit trail.

Write structured log records (delivery, bounce, deferral, reception) to durable storage.
Include message ID, sender, recipient, timestamp, remote server response, retry count.
Support log rotation and configurable log directory.

#### 5. Bounce Classification and DSN Generation
Bounce handling updates `Email.status` to `:permanent_failure` but no DSN messages are
generated and no granular bounce classification is applied.

Classify SMTP error responses into granular categories (permanent, transient, content,
network, auth, etc.). Generate RFC 3464 DSN messages for permanent failures. Support a
configurable bounce classification ruleset.

---

### High -- Needed Within Weeks of Production Launch

#### 6. Dynamic Traffic Shaping
`Epoxi.ProviderPolicy` has hardcoded delivery parameters per ISP. No runtime adjustment
based on remote SMTP responses (e.g., 421 throttling, 452 too many recipients).

Parse remote SMTP response codes and dynamically adjust connection rate, message rate,
and batch size for throttled domains. Persist shaping state across restarts.

#### 7. TTL-aware DNS Cache + Full DNS Resolution
`Epoxi.DNS.MxLookup` caches MX records in `:persistent_term` with no TTL. Cache entries
never expire. No PTR, A, or TXT record support.

Implement TTL-respecting DNS cache. Add PTR lookups (for FCrDNS on inbound), TXT lookups
(for SPF), and A/AAAA lookups. Support configurable resolvers and negative caching.

#### 8. Queue Management API (Suspend, Cancel, Inspect)
No API to suspend delivery to a specific domain, cancel queued messages, or inspect
individual queued messages.

API endpoints for: suspend delivery to domain/pool, cancel messages by queue/routing-key/
message-ID, list queue contents with filtering, force-retry deferred messages, rebind
messages to different queues.

#### 9. SPF Verification on Inbound
No SPF checking on inbound SMTP connections.

Validate `MAIL FROM` sender against SPF DNS records. Add `Authentication-Results` header
with SPF pass/fail/softfail/neutral result. Support policy hooks to reject on SPF hard-fail.

#### 10. Configurable Per-Egress-Path SMTP Auth (Outbound)
`SmtpConfig` has `username`/`password` fields but they are applied uniformly to all outbound
connections with no per-domain or per-pool configuration.

Support per-egress-path SMTP AUTH configuration. Allow different credentials per destination
(for smart-host routing). Support PLAIN, LOGIN mechanisms on outbound.

---

### Medium -- Needed Within the First Quarter of Production

#### 11. Webhook / Event Publishing
No mechanism to push delivery events to external systems in real time.

Publish delivery, bounce, deferral, and reception events to configurable HTTP webhook
endpoints. Support retry and backpressure for webhook delivery.

#### 12. Prometheus Metrics Export
Telemetry events are emitted but no metrics exporter is running.

Add a Prometheus-compatible metrics endpoint (`GET /metrics`). Export queue depth, delivery
throughput, bounce rate, retry counts, SMTP connection pool utilization, node health.

#### 13. Tenant Persistence
`Epoxi.Tenant` struct exists with full validation but has no storage backend. Tenant data
is lost on restart. No HTTP CRUD endpoints for tenants.

Persist tenant records to durable storage. Expose `POST/GET/PUT/DELETE /admin/tenants` API.
Associate DKIM configs with verified tenant domain ownership. Support tenant-level rate
limiting and pipeline isolation.

#### 14. Memory Pressure Management
No memory limits or back-pressure. Under sustained load with queue buildup, Epoxi can
exhaust VM memory and crash.

Monitor VM memory usage. At a configurable soft limit, begin shrinking in-memory queue
state (swap to DETS). At a hard limit, reject new inbound connections.

#### 15. DKIM Verification on Inbound
Epoxi can sign outbound mail but cannot verify DKIM signatures on inbound messages.

Verify DKIM signatures on inbound DATA. Add `Authentication-Results` header with DKIM
pass/fail/neutral per signature. Support both RSA and Ed25519 verification.

#### 16. DKIM Ed25519 Support
DKIM signing uses RSA-SHA256 only via `mimemail`. Ed25519 is not supported.

Support Ed25519 DKIM signing for outbound messages. May require replacing or extending
the signing implementation beyond `mimemail`.

---

### Nice-to-Have -- Competitive Differentiation

#### 17. ARC (Authenticated Received Chain) Signing and Verification
Sign outbound forwarded messages with ARC to preserve authentication results through
forwarding chains. Verify ARC on inbound for mailing list and forwarder compatibility.

#### 18. Feedback Loop (FBL) Processing
Accept inbound FBL/ARF reports from ISPs. Parse complaint messages, extract original
recipient, update suppression lists. Log FBL events for unsubscribe automation.

#### 19. Alternative Delivery Protocols (AMQP / Kafka / NATS / HTTP)
Support routing messages via AMQP, Kafka, NATS, or HTTP for architectures where Epoxi
acts as a policy gateway to downstream delivery systems.

#### 20. DANE and MTA-STS Support
Support TLSA DNS records (DANE) for authenticated TLS to destinations that publish them.
Support MTA-STS policy fetching and enforcement.

#### 21. Proxy Protocol Support (HAProxy / SOCKS5)
Support HAProxy PROXY protocol on inbound for true client IP preservation behind load
balancers. Support SOCKS5 proxy and HAProxy for outbound source IP binding.

#### 22. Clustered Shared Throttles (Redis)
Integrate Redis for cluster-wide shared throttle state. Throttle limits for a domain
should apply across all nodes collectively, not per-node.

#### 23. Dynamic Configuration Reload
Support live reloading of pipeline policies, DKIM configs, provider rules, and egress
path parameters without downtime.

#### 24. Kubernetes / Production Deployment Tooling
Production-grade OTP release with `mix release`. Proper liveness/readiness HTTP probes.
Graceful shutdown with queue draining. Docker image. Optional Helm chart.
