# CLAUDE.local.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build and Run

```bash
# Compile the project
mix compile

# Run the application
mix run

# Run with interactive Elixir shell
iex -S mix
```

### Testing

```bash
# Run all tests
mix test

# Run a specific test file
mix test test/path/to/test_file.exs

# Run a specific test (by line number)
mix test test/path/to/test_file.exs:line_number

# Run distributed tests
mix test --include distributed
```

### Quality and Analysis

```bash
# Run type checking with Dialyxir
mix dialyxir

# Run code style and quality checks with Credo
mix credo
```

### Dependencies

```bash
# Get dependencies
mix deps.get

# Update dependencies
mix deps.update
```

## Project Architecture

Epoxi is an Elixir OTP-based Mail Transfer Agent (MTA) and Mail Delivery Agent (MDA) designed for high-volume, fault-tolerant email delivery.

### Core Components

1. **Email Handling**

   - `Epoxi.Email`: Struct representing an email message with delivery status tracking.
   - `Epoxi.Render`: Responsible for encoding emails into proper MIME format.
   - `Epoxi.SmtpClient`: Sends emails to SMTP servers via gen_smtp library.
   - `Epoxi.SmtpServer`: Receives incoming emails.
   - `Epoxi.SmtpConfig`: Configuration for SMTP connections.

2. **Queue Management**

   - `Epoxi.Queue`: Durable queue implementation using ETS and DETS for hybrid in-memory/persistent storage.
   - `Epoxi.Queue.Processor`: Broadway pipeline for processing queued emails.
   - `Epoxi.Queue.Producer`: Produces messages for the Broadway pipeline from queues.

3. **Web Interface**

   - `Epoxi.Endpoint`: HTTP(S) endpoint using Bandit for web interactions.
   - `Epoxi.Router`: Routes HTTP requests to appropriate handlers.

4. **Telemetry**

   - `Epoxi.Telemetry`: Metrics collection and reporting.

5. **Distributed Architecture**
   - `Epoxi.Cluster`: Helpers for clustering and distribution.
   - `Epoxi.Node`: Node management and distributed operations.

### Data Flow

1. Emails are created as `Epoxi.Email` structs.
2. They can be sent via:
   - `Epoxi.send/2`: Synchronous sending
   - `Epoxi.send_async/3`: Asynchronous sending
   - `Epoxi.send_bulk/2`: Bulk sending with connection pooling
3. Emails are processed by:
   - Direct delivery via `SmtpClient`
   - Queuing in `Epoxi.Queue` for later processing
   - Processing by `Epoxi.Queue.Processor` using Broadway
4. Failed emails can:
   - Retry with exponential backoff
   - Be moved to a dead-letter queue for later inspection

### Persistence

The queue system uses:

- ETS (in-memory) tables for fast operations
- DETS (disk-based) tables for persistence
- Periodic syncing between ETS and DETS for durability
- Configurable sync intervals

### Telemetry and Monitoring

Epoxi implements the Elixir Telemetry standard for metrics collection, allowing integration with various monitoring systems.

## Roadmap

The end goal for Epoxi is to have feature parity with Kumo MTA, but implemented in a simpler way leveraging the BEAM and Elixir's capabilities. Below is a roadmap of features organized by level of effort (from lowest to highest).

### Phase 1: Core Enhancements (Low Effort)

- **Enhanced Retry Logic**

  - Implement more sophisticated retry strategies based on failure type
  - Add backoff algorithms for different error scenarios
  - Add support for custom retry strategies per domain or recipient

- **Basic Throttling**

  - Implement connection rate limiting per destination domain
  - Add basic sending rate limiting (messages per minute)
  - Develop simple IP rotation strategies

- **Bounce Classification**

  - Add detailed bounce categorization (permanent vs. temporary)
  - Implement bounce logging with structured data
  - Create simple bounce reporting mechanisms

- **Configuration Enhancements**
  - Add support for runtime configuration updates
  - Develop domain-specific configurations
  - Implement basic sender authentication configuration (SPF, DKIM)
  - Develop defining cluster topology, levereging `libcluster`.
  - Enable the HTTP (Bandit) endpoint to be started optionally.
  - Develop strategy to define policies and config as files, like TOML, YAML, or JSON.

### Phase 2: Advanced Features (Medium Effort)

- **MX-Based Routing**

  - Implement intelligent MX lookup and caching
  - Add MX rollup for similar domains
  - Develop destination-based routing strategies

- **Enhanced Queue Management**

  - Add priority queues for different message types
  - Implement tenant-based queue isolation
  - Add support for campaign-based queuing
  - Develop queue inspection and management tools

- **IP Pooling**

  - Implement basic IP pool management
  - Add routing to specific IP pools based on message attributes
  - Create IP pool health monitoring
  - Develop fallback mechanisms between pools

- **Monitoring Dashboard**

  - Create a basic web UI for monitoring
  - Add real-time metrics visualization
  - Implement delivery success rate tracking
  - Add alerting for delivery issues

- **Advanced Telemetry**
  - Expand telemetry events for detailed monitoring
  - Add integration with common monitoring systems (Prometheus, Grafana)
  - Implement detailed performance metrics

### Phase 3: Enterprise Features (High Effort)

- **Intelligent Throttling**

  - Implement automatic throttling based on recipient domain responses
  - Add adaptive sending rates based on historical performance
  - Develop tenant-level throttling and quality of service
  - Implement global and per-domain connection pooling

- **IP Warmup**

  - Create automated IP warmup scheduling
  - Implement reputation monitoring for new IPs
  - Add dynamic volume adjustment based on delivery feedback
  - Develop multi-stage warmup profiles for different ISPs
  - Build historical performance tracking for warmup progress

- **Advanced Analytics**

  - Build comprehensive delivery analytics
  - Implement machine learning for optimal delivery scheduling
  - Add predictive delivery success modeling
  - Create detailed reporting dashboards

- **Comprehensive Admin Interface**

  - Develop full-featured admin UI
  - Add user management with role-based access control
  - Implement configuration management through UI
  - Create template management system

- **Horizontal Scaling**
  - Enhance cluster management for high availability
  - Implement cross-node queue synchronization
  - Add distributed throttling coordination
  - Develop automatic load balancing between nodes

### Phase 4: Parity and Beyond (Highest Effort)

- **Lua Scripting Engine**

  - Implement Lua scripting support for customization
  - Add hooks for all major processing points
  - Create a library of common scripts
  - Build documentation for script development

- **High Performance Optimizations**

  - Optimize for 1M+ messages per hour per node
  - Implement advanced storage engines for the queue
  - Add parallel processing capabilities
  - Optimize network I/O for high-volume scenarios

- **Advanced Security Features**

  - Implement comprehensive authentication methods
  - Add encryption for sensitive data
  - Develop audit logging for all actions
  - Add compliance features for various regulations

- **Enterprise Integration**
  - Add support for AMQP, Kafka, and other messaging systems
  - Implement webhooks for event notifications
  - Create API for third-party integrations
  - Add support for custom storage backends
