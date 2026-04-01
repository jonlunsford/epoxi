# Clustering

Epoxi is designed for distributed deployment across multiple Erlang nodes. The cluster coordinates IP allocation, pipeline placement, and email routing across nodes using ERPC and automatic node discovery.

## Cluster Architecture

```
                    ┌──────────────────────────────────────┐
                    │            NodeRegistry               │
                    │  (GenServer on each node)             │
                    │                                       │
                    │  ┌─────────┐  ┌──────────┐  ┌──────┐ │
                    │  │ Cluster │  │IpManager │  │Pipe- │ │
                    │  │ State   │  │          │  │line  │ │
                    │  │         │  │          │  │Mgr   │ │
                    │  └─────────┘  └──────────┘  └──────┘ │
                    └──────────────────┬───────────────────┘
                                       │
                    ┌──────────────────┤───────────────────┐
                    │                  │                    │
               ┌────▼────┐       ┌────▼────┐         ┌────▼────┐
               │ Node A  │       │ Node B  │         │ Node C  │
               │         │  ERPC │         │  ERPC   │         │
               │Pipeline │◄─────►│Pipeline │◄───────►│Pipeline │
               │Pipeline │       │Pipeline │         │Pipeline │
               └─────────┘       └─────────┘         └─────────┘
```

## Components

### NodeRegistry

`Epoxi.NodeRegistry` is the central GenServer on each node. It maintains the cluster state and provides a unified API by delegating to three specialized modules:

- **`Epoxi.NodeManager`** -- Node registration, health checking, optimal node selection
- **`Epoxi.IpManager`** -- IP allocation across pools, weighting, pool statistics
- **`Epoxi.PipelineManager`** -- Pipeline registration, routing key lookup, load balancing recommendations

The registry automatically monitors cluster membership via `:net_kernel.monitor_nodes/2` and handles `:nodeup`/`:nodedown` events.

### Cluster State

`Epoxi.Cluster` maintains the data structure for cluster state:

```elixir
%Epoxi.Cluster{
  node_count: 3,
  nodes: [%Epoxi.Node{name: :"epoxi@10.0.0.1", status: :up, ...}, ...],
  ip_pools: %{
    default: %{
      :"epoxi@10.0.0.1" => ["10.0.0.1", "10.0.0.2"],
      :"epoxi@10.0.0.2" => ["10.0.0.3"]
    }
  }
}
```

### Node Communication

`Epoxi.Node.route_call/4` and `route_cast/4` transparently handle local vs. remote dispatch:

```elixir
# If target is the local node, calls apply(Epoxi, :start_pipeline, [opts])
# If target is remote, calls :erpc.call(:"epoxi@10.0.0.2", Epoxi, :start_pipeline, [opts])
Epoxi.Node.route_call(target_node, Epoxi, :start_pipeline, [opts])
```

Both functions emit telemetry events for route count and latency.

## IP Pool Management

Nodes are organized into IP pools. Each node's network interfaces are discovered automatically and assigned to pools.

### IP Allocation Strategies

When routing emails, IPs are allocated from the specified pool using one of four strategies:

| Strategy | Description |
|---|---|
| `:round_robin` | Cycles through IPs sequentially |
| `:weighted` | Distributes based on IP weights (default) |
| `:least_used` | Picks the least-loaded IP (falls back to round-robin) |
| `:random` | Random selection |

```elixir
# Allocate IPs to emails from the "transactional" pool
emails = Epoxi.NodeRegistry.allocate_ips(emails, :transactional, :weighted)

# Set IP weight (higher = more traffic)
Epoxi.NodeRegistry.set_ip_weight("10.0.0.1", 100)
Epoxi.NodeRegistry.set_ip_weight("10.0.0.2", 50)

# Query pool information
Epoxi.NodeRegistry.get_pool_ips(:default)
Epoxi.NodeRegistry.get_node_ips(:"epoxi@10.0.0.1")
Epoxi.NodeRegistry.find_ip_owner("10.0.0.1")
Epoxi.NodeRegistry.get_all_cluster_ips()
```

## Pipeline Distribution

Pipelines are distributed across the cluster based on routing keys (MX host + IP combinations).

### Pipeline Placement

When new email batches arrive, the router:

1. Checks if a pipeline already exists for the routing key.
2. If not, selects the optimal node using the `:least_pipelines` strategy.
3. Starts the pipeline on the selected node via ERPC.
4. Enqueues the batch to the pipeline's inbox queue.

```elixir
# Find which node handles a routing key
{:ok, node} = Epoxi.NodeRegistry.find_node_for_routing_key("gmail_10_0_0_1")

# Get pipeline distribution stats
stats = Epoxi.NodeRegistry.get_pipeline_stats()

# Select optimal node for a new pipeline
{:ok, node} = Epoxi.NodeRegistry.select_optimal_node_for_pipeline(:default, :least_pipelines)
```

### Pipeline Monitoring

`Epoxi.PipelineMonitor` provides health checking and cluster statistics:

```elixir
# Health check all pipelines
results = Epoxi.PipelineMonitor.health_check_all()

# Health check pipelines for a specific routing key
results = Epoxi.PipelineMonitor.health_check_routing_key("gmail_10_0_0_1")

# Get cluster-wide statistics
stats = Epoxi.PipelineMonitor.get_cluster_stats()

# Start a pipeline on the optimal node
{:ok, pid} = Epoxi.PipelineMonitor.start_pipeline_optimal(batch, :default)

# Stop pipelines by routing key
:ok = Epoxi.PipelineMonitor.stop_pipeline_by_routing_key("gmail_10_0_0_1")
```

## Node Selection Strategies

The `NodeManager` supports multiple strategies for selecting nodes:

| Strategy | Description |
|---|---|
| `:round_robin` | Simple rotation through available nodes |
| `:least_loaded` | Selects node with lowest calculated load |
| `:random` | Random selection |
| `:capabilities` | Filter by node capabilities (currently returns all nodes) |

Node health is calculated as a boolean based on `:up` status. Node load is calculated as `pipeline_count * 1.0`.

## Setting Up a Cluster

### 1. Configure Erlang Distribution

Each node needs a unique name and a shared cookie:

```bash
# Node A
elixir --name epoxi@10.0.0.1 --cookie epoxi_secret -S mix run --no-halt

# Node B
elixir --name epoxi@10.0.0.2 --cookie epoxi_secret -S mix run --no-halt
```

### 2. Connect Nodes

Nodes discover each other through standard Erlang distribution. Connect from any node:

```elixir
Node.connect(:"epoxi@10.0.0.2")
```

Once connected, the `NodeRegistry` automatically detects the new node and registers it with the cluster state.

### 3. Verify

```elixir
# Check cluster state
Epoxi.NodeRegistry.list_nodes()

# Check IP pools
Epoxi.NodeRegistry.get_pool_ips(:default)

# Check pipeline distribution
Epoxi.NodeRegistry.get_pipeline_stats()
```

## Fallback Routing

If the primary routing path fails (e.g., the selected node can't start a pipeline), the router falls back to selecting a random node from the IP pool and enqueuing the batch there. This ensures email delivery even during partial cluster failures.
