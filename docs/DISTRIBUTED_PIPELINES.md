# Distributed Pipeline Discovery System

This document describes the distributed pipeline discovery system implemented in Epoxi for intelligent email routing across a cluster.

## Overview

The system provides dynamic routing of email batches to appropriate Broadway pipelines based on routing keys, with automatic pipeline creation, load balancing, and health monitoring across distributed nodes.

## Key Components

### 1. Node Pipeline Tracking (`Epoxi.Node`)

Enhanced the Node module to track running pipelines:
- `pipeline_info` type for comprehensive pipeline metadata
- Pipeline registration/unregistration functions
- Support for local and remote pipeline discovery via RPC
- Automatic inclusion of pipeline information in node state

### 2. Cluster-wide Pipeline Discovery (`Epoxi.Cluster`)

Added cluster-wide pipeline management functions:
- `find_all_pipelines/0,1` - Discover all pipelines across cluster nodes
- `find_pipelines_by_routing_key/1,2` - Find pipelines for specific routing keys
- `find_node_for_routing_key/1,2` - Locate optimal nodes for routing
- `get_pipeline_stats/0,1` - Cluster pipeline analytics and distribution

### 3. Intelligent Email Routing (`Epoxi.Email.Router`)

Centralized routing module following "tell, don't ask" principles:
- Automatic batch creation from email lists
- Pipeline discovery and creation for routing keys
- Load balancing across available nodes
- Fallback routing when primary routing fails
- Comprehensive routing statistics and error handling

### 4. Pipeline Supervisor Enhancement (`Epoxi.Queue.PipelineSupervisor`)

Enhanced supervisor with automatic pipeline registry management:
- Automatic pipeline registration on start
- Automatic pipeline unregistration on stop
- Pipeline metadata extraction and storage
- ETS table management for pipeline tracking

### 5. Pipeline Monitoring (`Epoxi.PipelineMonitor`)

Comprehensive monitoring and administration capabilities:
- Health checking pipelines across all nodes
- Pipeline performance and load monitoring
- Administrative start/stop operations
- Cluster rebalancing capabilities
- Pipeline statistics and insights

## Usage Examples

### Basic Email Routing

```elixir
# Route emails using the intelligent router
emails = [
  %Epoxi.Email{to: ["user@gmail.com"], delivery: %{ip: "192.168.1.1"}},
  %Epoxi.Email{to: ["user@yahoo.com"], delivery: %{ip: "192.168.1.2"}}
]

{:ok, summary} = Epoxi.Email.Router.route_emails(emails, :default)
# => %{total_emails: 2, total_batches: 2, successful_batches: 2, 
#      failed_batches: 0, new_pipelines_started: 2}
```

### Pipeline Discovery

```elixir
# Find all pipelines across the cluster
pipeline_map = Epoxi.Cluster.find_all_pipelines()
# => %{node1@host: [%{name: :pipeline1, routing_key: "gmail.com_192_168_1_1", ...}]}

# Find pipelines for a specific routing key
{:ok, node} = Epoxi.Cluster.find_node_for_routing_key("gmail.com_192_168_1_1")
```

### Health Monitoring

```elixir
# Check health of all pipelines
health_results = Epoxi.PipelineMonitor.health_check_all()

# Get comprehensive cluster statistics
stats = Epoxi.PipelineMonitor.get_cluster_stats()
# => %{pipeline_stats: %{...}, health_summary: %{healthy: 5, unhealthy: 0}, ...}
```

### Administrative Operations

```elixir
# Start a pipeline on the optimal node
policy = Epoxi.Queue.PipelinePolicy.new(name: :custom_pipeline)
{:ok, {node_name, pid}} = Epoxi.PipelineMonitor.start_pipeline_optimal(policy, :default)

# Stop pipelines by routing key
{:ok, stopped_count} = Epoxi.PipelineMonitor.stop_pipeline_by_routing_key("gmail.com_192_168_1_1")
```

## HTTP Admin Endpoints

The system provides HTTP endpoints for monitoring and administration:

- `GET /admin/pipelines` - Get cluster-wide pipeline statistics
- `GET /admin/pipelines/health` - Get health check results for all pipelines
- `GET /admin/pipelines/:routing_key` - Get health check for specific routing key

## Architecture Benefits

1. **Automatic Pipeline Management**: Pipelines are created and destroyed as needed based on email routing patterns
2. **Load Balancing**: Intelligent distribution of pipelines across available nodes
3. **Fault Tolerance**: Health monitoring and automatic failover capabilities
4. **Scalability**: Horizontal scaling through distributed node architecture
5. **Monitoring**: Comprehensive visibility into pipeline health and performance
6. **Flexibility**: Configurable routing policies and pipeline parameters

## Configuration

Pipeline policies can be configured with various parameters:

```elixir
policy = Epoxi.Queue.PipelinePolicy.new(
  name: :custom_pipeline,
  max_connections: 10,
  max_retries: 5,
  batch_size: 100,
  batch_timeout: 5_000,
  allowed_messages: 1000,
  message_interval: 60_000
)
```

## Integration Points

The system integrates with existing Epoxi components:
- HTTP endpoints for email submission
- SMTP server for email reception
- Queue system for message persistence
- Telemetry for monitoring and metrics
- Cluster management for node coordination

This architecture provides a robust foundation for distributed email processing with intelligent routing and automatic scaling capabilities.
