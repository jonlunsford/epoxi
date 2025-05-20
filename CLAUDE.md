# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Epoxi is an Elixir OTP-based Mail Transfer Agent (MTA) and Mail Delivery Agent (MDA) designed for high-volume, fault-tolerant email delivery. The name is inspired by the EPOXI spacecraft.

## Goals and Requirements

- Create a high-performance, reliable email delivery system
- Support both synchronous and asynchronous email sending
- Implement intelligent retry logic with configurable backoff patterns
- Provide bulk email delivery capabilities with connection pooling
- Expose both SMTP server and HTTP API interfaces
- Ensure fault tolerance through OTP principles
- Maintain comprehensive metrics via telemetry
- Support distributed operation across multiple nodes
- Keep external dependencies to a minimum for easier distribution
- Leverage BEAM VM capabilities (ETS, DETS, networking, epmd, OTP) before adding dependencies

## Architecture Guidelines

- Follow OTP design principles for fault tolerance
- Use Broadway pipelines for efficient message processing
- Design with clean boundaries between components
- Implement the "let it crash" philosophy with proper supervision
- Build for horizontal scalability
- Maintain backward compatibility with existing APIs
- Prefer built-in BEAM/OTP solutions over external libraries
- Consider distributability in all design decisions
- When external libraries are necessary, favor lightweight dependencies with minimal sub-dependencies

## Commands

- Build: `mix compile`
- Run: `mix run --no-halt`
- Run tests: `mix test`
- Run single test: `mix test test/path/to/test.exs:line_number`
- Format code: `mix format`
- Lint: `mix credo`
- Type check: `mix dialyzer`
- Run iex: `iex -S mix`

## Code Style

- Use `@moduledoc` and `@doc` for module and function documentation
- Add `@type` specifications for structs
- Add `@spec` type specifications for public functions
- Keep modules focused on a single responsibility
- Follow standard Elixir naming conventions (`snake_case` for variables/functions)
- Prefer pattern matching in function heads over conditionals
- Format with `mix format` (2 space indentation)
- Handle errors using tagged tuples `{:ok, result}` or `{:error, reason}`
- Log errors with appropriate levels (debug, info, warn, error)
- Keep modules and functions small and focused
- Use the commonly used token pattern for Elixir. Where a "token" is a data structure, struct, etc and should be passed in as the first argument to functions
- Keep functions pure when possible, avoid side effects
- Functions with multiple clauses should return the same type
- Use tagged tuples where possible

## Testing

- Every module should have a corresponding test module
- Use ExUnit for tests
- Tests should be async when possible (`use ExUnit.Case, async: true`)
- Follow the AAA pattern: Arrange, Act, Assert
- Use mocks sparingly, prefer explicit contracts and dependency injection

## Current Development Focus

- Implementing telemetry for comprehensive metrics
- Enhancing the HTTP endpoint functionality
- Improving DKIM support for better email deliverability
- Refining pipeline acknowledgment for reliable message processing
- Building out distributed capabilities
