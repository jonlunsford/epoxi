# Epoxi

**Epoxi** is a high-performance, fault-tolerant Mail Transfer Agent (MTA) and Mail Delivery Agent (MDA) built with Elixir/OTP. Named after NASA's EPOXI mission, it's designed form mission-critical email delivery.

## Features

- **High-Performance**: Built on Broadway pipelines for concurrent email processing
- **Fault-Tolerant**: Automatic retry logic with exponential backoff
- **Distributed**: Multi-node cluster support with automatic load balancing
- **Durable Queues**: Hybrid ETS/DETS storage for fast access with persistence
- **Batch Processing**: Efficient bulk email delivery with connection pooling
- **Observability**: Comprehensive telemetry and monitoring
- **Smart Routing**: Domain-based email routing and IP pool management
- **Real-time**: HTTP API for immediate email queuing and status monitoring

## Installation

Add Epoxi to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:epoxi, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Basic Email Sending

```elixir
# Create an email
email = %Epoxi.Email{
  from: "sender@example.com",
  to: ["recipient@example.com"],
  subject: "Hello from Epoxi!",
  html: "<h1>Welcome!</h1><p>This is a test email from Epoxi.</p>",
  text: "Welcome! This is a test email from Epoxi."
}

# Send synchronously
{:ok, receipt} = Epoxi.send(email)

# Send asynchronously
:ok = Epoxi.send_async(email)

# Send multiple emails in bulk
emails = [email1, email2, email3]
{:ok, results} = Epoxi.send_bulk(emails)
```

### Advanced Configuration

```elixir
# Configure SMTP settings
opts = [
  relay: "smtp.example.com",
  port: 587,
  username: "user@example.com",
  password: "password",
  ssl: true,
  tls: :always
]

{:ok, receipt} = Epoxi.send(email, opts)
```

### Pipeline Management

```elixir
# Start a custom pipeline with specific policy
policy = Epoxi.Queue.PipelinePolicy.new(
  name: :high_priority,
  max_connections: 20,
  batch_size: 50,
  batch_timeout: 2_000,
  max_retries: 3
)

{:ok, pid} = Epoxi.start_pipeline(policy)
```

## Architecture

### Core Components

#### Email Processing Pipeline

- **`Epoxi.Email`**: Email struct with retry logic and delivery tracking
- **`Epoxi.Queue.Pipeline`**: Broadway-based processing pipeline
- **`Epoxi.Queue.Producer`**: Produces emails from durable queues
- **`Epoxi.SmtpClient`**: SMTP delivery client with batch support

#### Distributed Architecture

- **`Epoxi.Node`**: Manages distributed node communication via ERPC
- **`Epoxi.NodeRegistry`**: Tracks cluster nodes and their state
- **`Epoxi.Cluster`**: Cluster formation and management

#### Queue Management

- **`Epoxi.Queue`**: Durable queue with ETS/DETS hybrid storage
- **`Epoxi.Queue.PipelinePolicy`**: Configurable pipeline policies
- **`Epoxi.Queue.PipelineSupervisor`**: Manages pipeline processes

### Key Design Patterns

- **Broadway Pipelines**: Email processing uses Broadway for concurrent, fault-tolerant batch processing
- **Distributed RPC**: Node communication uses ERPC for inter-node calls with telemetry
- **Durable Queues**: Hybrid ETS/DETS storage for fast access with persistence
- **Retry Logic**: Exponential backoff retry handling in Email struct
- **Policy-Based Configuration**: Pipeline behavior controlled by configurable policies

## Configuration

### Application Configuration

```elixir
# config/config.exs
config :epoxi,
  endpoint_options: [
    port: 4000,
    scheme: :http
  ]

# config/prod.exs
config :epoxi,
  endpoint_options: [
    port: 80,
    scheme: :http
  ]
```

### Pipeline Policies

```elixir
# Default pipeline policy
default_policy = Epoxi.Queue.PipelinePolicy.new(
  name: :default,
  max_connections: 10,
  max_retries: 5,
  batch_size: 100,
  batch_timeout: 1_000,
  allowed_messages: 1000,
  message_interval: 60_000
)
```

## HTTP API

Epoxi provides a RESTful HTTP API for email management:

### Send Emails

```bash
curl -X POST http://localhost:4000/messages \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "from": "sender@example.com",
      "to": ["recipient@example.com"],
      "subject": "Hello from API",
      "html": "<p>Hello from Epoxi API!</p>",
      "text": "Hello from Epoxi API!"
    },
    "ip_pool": "default"
  }'
```

### Monitor Pipelines

```bash
# Get pipeline statistics
curl http://localhost:4000/admin/pipelines

# Health check all pipelines
curl http://localhost:4000/admin/pipelines/health

# Health check specific routing key
curl http://localhost:4000/admin/pipelines/example.com
```

### Health Check

```bash
curl http://localhost:4000/ping
```

## Distributed Usage

### Cluster Management

```elixir
# Initialize cluster
cluster = Epoxi.Cluster.init()

# Get current cluster state
cluster = Epoxi.Cluster.get_current_state()

# Find nodes in specific IP pool
nodes = Epoxi.Cluster.find_nodes_in_pool(cluster, :production)

# Get all IPs in a pool
ips = Epoxi.Cluster.get_pool_ips(cluster, :production)
```

### Node Communication

```elixir
# Route calls to specific nodes
target_node = Epoxi.Node.from_node(:node@host)

# Synchronous call
result = Epoxi.Node.route_call(target_node, Epoxi.Queue, :length, [:mail_queue])

# Asynchronous cast
Epoxi.Node.route_cast(target_node, Epoxi.Queue, :enqueue, [:mail_queue, email])
```

## Queue Management

### Durable Queues

```elixir
# Start a durable queue
{:ok, pid} = Epoxi.Queue.start_link(name: :mail_queue)

# Enqueue messages
Epoxi.Queue.enqueue(:mail_queue, email, priority: 1)

# Enqueue multiple messages
Epoxi.Queue.enqueue_many(:mail_queue, [email1, email2], priority: 0)

# Dequeue messages
{:ok, email} = Epoxi.Queue.dequeue(:mail_queue)

# Check queue status
length = Epoxi.Queue.length(:mail_queue)
empty? = Epoxi.Queue.empty?(:mail_queue)

# Force sync to disk
Epoxi.Queue.sync(:mail_queue)
```

## Email Routing

### Smart Domain Routing

```elixir
# Emails are automatically routed based on recipient domain
email = %Epoxi.Email{
  from: "sender@example.com",
  to: ["user@gmail.com", "user@yahoo.com"],
  subject: "Multi-domain test",
  text: "This will be routed to gmail.com and yahoo.com pipelines"
}

# The system automatically creates separate pipelines for each domain
Epoxi.send_async(email)
```

### IP Pool Management

```elixir
# Route emails to specific IP pools
emails = [email1, email2, email3]
{:ok, summary} = Epoxi.Email.Router.route_emails(emails, :production_pool)
```

## Monitoring and Observability

### Telemetry Events

Epoxi emits comprehensive telemetry events:

```elixir
# Queue operations
:telemetry.execute([:epoxi, :queue, :sync], %{count: 100}, %{queue: :mail_queue})
:telemetry.execute([:epoxi, :queue, :destroyed], %{}, %{queue: :mail_queue})

# Pipeline operations
:telemetry.execute([:epoxi, :pipeline, :message_processed], %{count: 1}, %{pipeline: :default})

# Node routing
:telemetry.execute([:epoxi, :router, :route, :count], %{count: 1}, %{source_node: :node1, target_node: :node2})
```

### Pipeline Monitoring

```elixir
# Get cluster statistics
stats = Epoxi.PipelineMonitor.get_cluster_stats()

# Health check all pipelines
health = Epoxi.PipelineMonitor.health_check_all()

# Health check specific routing key
health = Epoxi.PipelineMonitor.health_check_routing_key("example.com")
```

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run tests including distributed cluster tests
mix test --include distributed

# Run specific test file
mix test test/epoxi/email_test.exs

# Run test at specific line
mix test test/epoxi/email_test.exs:123
```

### Code Quality

```bash
# Format code
mix format

# Run static analysis
mix credo

# Run type checking
mix dialyzer
```

### Interactive Development

```bash
# Start interactive shell with application
iex -S mix

# Run application in foreground
mix run --no-halt
```

## Production Deployment

### Docker Support

```dockerfile
FROM elixir:1.18-alpine

WORKDIR /app
COPY . .

RUN mix deps.get && mix compile

EXPOSE 4000
CMD ["mix", "run", "--no-halt"]
```

### Environment Variables

```bash
# SMTP Configuration
export EPOXI_SMTP_RELAY="smtp.example.com"
export EPOXI_SMTP_PORT="587"
export EPOXI_SMTP_USERNAME="user@example.com"
export EPOXI_SMTP_PASSWORD="password"

# Cluster Configuration
export EPOXI_NODE_NAME="epoxi@node1.example.com"
export EPOXI_COOKIE="your-secret-cookie"
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Elixir best practices and avoid [anti-patterns](https://hexdocs.pm/elixir/main/what-anti-patterns.html)
- Add `@spec` and `@doc` to all public functions
- Add `@moduledoc` to all modules
- Write comprehensive tests
- Use conventional commit messages
- Run `mix format`, `mix test`, `mix credo`, and `mix dialyzer` before submitting

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by NASA's EPOXI mission and its mission-critical reliability requirements
- Built with [Broadway](https://github.com/dashbitco/broadway) for robust data processing
- Uses [gen_smtp](https://github.com/Vagabond/gen_smtp) for SMTP functionality
- Powered by [Bandit](https://github.com/mtrudel/bandit) for HTTP serving

## Support

- 📖 [Documentation](https://hexdocs.pm/epoxi)
- 🐛 [Issue Tracker](https://github.com/your-org/epoxi/issues)
- 💬 [Discussions](https://github.com/your-org/epoxi/discussions)
- 📧 [Email Support](mailto:support@example.com)

---

**Epoxi** - Built for mission-critical email delivery. 🚀
