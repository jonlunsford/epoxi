# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Epoxi is an Elixir OTP-based Mail Transfer Agent (MTA) and Mail Delivery Agent (MDA) designed for high-volume, fault-tolerant email delivery. It's built like a spacecraft - hence the name after NASA's EPOXI mission.

## Development Commands

### Basic Commands

- `mix deps.get` - Install dependencies
- `mix compile` - Compile the project
- `mix test` - Run all tests
- `mix test --include distributed` - Run tests including distributed cluster tests
- `mix test test/path/to/file_test.exs` - Run specific test file
- `mix test test/path/to/file_test.exs:123` - Run test at specific line

### Code Quality

- `mix credo` - Run static code analysis
- `mix dialyzer` - Run type checking
- `mix format` - Format code

### Development Server

- `iex -S mix` - Start interactive shell with application
- `mix run --no-halt` - Run application in foreground

## Architecture Overview

### Core Components

1. **Email Processing Pipeline**

   - `Epoxi.Email` - Email struct with retry logic and delivery tracking
   - `Epoxi.Queue.Pipeline` - Broadway-based processing pipeline
   - `Epoxi.Queue.Producer` - Produces emails from durable queues
   - `Epoxi.SmtpClient` - SMTP delivery client with batch support

2. **Distributed Architecture**

   - `Epoxi.Node` - Manages distributed node communication via ERPC
   - `Epoxi.NodeRegistry` - Tracks cluster nodes and their state
   - `Epoxi.Cluster` - Cluster formation and management

3. **Queue Management**

   - `Epoxi.Queue` - Durable queue with ETS/DETS hybrid storage
   - `Epoxi.Queue.PipelinePolicy` - Configurable pipeline policies
   - `Epoxi.Queue.PipelineSupervisor` - Manages pipeline processes

4. **Supporting Systems**
   - `Epoxi.Render` - Email rendering and encoding
   - `Epoxi.Parsing` - Email parsing utilities
   - `Epoxi.Telemetry` - Metrics and observability

### Key Design Patterns

- **Broadway Pipelines**: Email processing uses Broadway for concurrent, fault-tolerant batch processing
- **Distributed RPC**: Node communication uses ERPC for inter-node calls with telemetry
- **Durable Queues**: Hybrid ETS/DETS storage for fast access with persistence
- **Retry Logic**: Exponential backoff retry handling in Email struct
- **Policy-Based Configuration**: Pipeline behavior controlled by configurable policies

## Testing

### Test Structure

- Unit tests for individual modules
- Integration tests for email delivery workflows
- Distributed tests for cluster functionality (tagged with `distributed: true`)
- Support modules in `test/support/` for test infrastructure

### Test Utilities

- `Epoxi.TestCluster` - Spawns distributed test nodes
- `Epoxi.TestSmtpServer` - Local SMTP server for testing
- Test helpers for common setup patterns

### Running Distributed Tests

Distributed tests require special setup and are excluded by default. Use `mix test --include distributed` to run them.

## Configuration

Configuration is environment-specific:

- `config/config.exs` - Base configuration
- `config/dev.exs` - Development settings
- `config/test.exs` - Test environment with Broadway.DummyProducer
- `config/prod.exs` - Production configuration

Key configuration areas:

- Endpoint options for HTTP interface
- Producer module selection (real vs dummy for testing)
- Queue names and directories
- SMTP client settings

## Common Development Patterns

### Adding New Pipeline Policies

1. Extend `Epoxi.Queue.PipelinePolicy` struct
2. Update `broadway_opts/1` function
3. Add tests for new policy behavior

### Extending Email Processing

1. Add new fields to `Epoxi.Email` struct
2. Update rendering logic in `Epoxi.Render`
3. Consider batch processing implications

### Follow Elixir Best Bractices

1. Avoid anti-patterns:
   a. Fetch: https://raw.githubusercontent.com/elixir-lang/elixir/refs/heads/main/lib/elixir/pages/anti-patterns/code-anti-patterns.md
   b. Fetch: https://raw.githubusercontent.com/elixir-lang/elixir/refs/heads/main/lib/elixir/pages/anti-patterns/design-anti-patterns.md
   c. Fetch: https://raw.githubusercontent.com/elixir-lang/elixir/refs/heads/main/lib/elixir/pages/anti-patterns/process-anti-patterns.md
2. Avoid try/catch for control flow.
3. Avoid exception handling for control flow.
4. Prefer tagged tuples and pattern matching for control flow.
5. Don't nest blocks (case, cond, etc.) more than one level deep, extract functions, and/or use `with` instead.
6. Prefer "let it crash" philosophy.
7. Prefer tell-dont-ask, single responsibility, pure functions.
8. Elixir is declarative, avoid imperative programming styles when possible.
9. Add @spec and @doc to all public functions.
10. Add @moduledoc to all modules.

### Feature Development Workflow

1. Commit relate changes with meaningful, conventional commit messages
2. Remove Claude as co-author.
3. When features have been completed ALWAYS:
   a. run `mix format` and commit all changes as "formatting".
   b. run `mix test` and fix any test failures.
   c. run `mix credo` and fix any code style issues.
   d. run `mix dialyzer` and fix any type issues.
4. Evaluate all changes when features are complete against:
   a. Fetch: https://raw.githubusercontent.com/elixir-lang/elixir/refs/heads/main/lib/elixir/pages/anti-patterns/code-anti-patterns.md
   b. Fetch: https://raw.githubusercontent.com/elixir-lang/elixir/refs/heads/main/lib/elixir/pages/anti-patterns/design-anti-patterns.md
   c. Fetch: https://raw.githubusercontent.com/elixir-lang/elixir/refs/heads/main/lib/elixir/pages/anti-patterns/process-anti-patterns.md
5. Open pull request with comprehensive description, interact with GitHub using `gh`

### MCP Usage

1. Use context 7 when unsure how libraries, or dependencies, work.
2. Use context 7 to double check your work and assumptions, regarding language and library APIs.

### Node Communication

Use `Epoxi.Node.route_call/4` and `Epoxi.Node.route_cast/4` for distributed operations. These functions handle local vs remote routing automatically.

## Dependencies

Key dependencies and their purposes:

- `broadway` - Concurrent data processing pipelines
- `gen_smtp` - SMTP client/server implementation
- `bandit` - HTTP server for endpoint
- `telemetry` - Metrics and observability
- `req` - HTTP client for external requests
- `credo` - Static code analysis
- `dialyxir` - Type checking
