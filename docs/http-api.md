# HTTP API

Epoxi exposes a JSON HTTP API for message injection and administration. The server is powered by Bandit and uses Plug.Router for routing.

## Health Check

```
GET /ping
```

Returns `200 OK` with body `pong!`. Use this for load balancer health checks.

## Message Injection

```
POST /messages
Content-Type: application/json
```

### Request Body

```json
{
  "message": {
    "from": "sender@example.com",
    "to": ["recipient@example.com"],
    "subject": "Hello from Epoxi",
    "html": "<p>Hello, <%= @name %>!</p>",
    "text": "Hello, <%= @name %>!",
    "data": {
      "recipient@example.com": {
        "name": "Alice"
      }
    }
  },
  "ip_pool": "default"
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `message.from` | string | yes | Sender email address |
| `message.to` | list | yes | Recipient email addresses |
| `message.subject` | string | yes | Email subject line |
| `message.html` | string | no | HTML body (supports EEx templates) |
| `message.text` | string | no | Plain text body (supports EEx templates) |
| `message.data` | map | no | Per-recipient template data, keyed by email address |
| `message.reply_to` | string | no | Reply-To header |
| `message.cc` | list | no | CC recipients |
| `message.bcc` | list | no | BCC recipients |
| `message.headers` | map | no | Additional email headers |
| `ip_pool` | string | no | IP pool for sending (default: `"default"`) |

### Response

```
200 OK

Successfully routed 3 emails in 1 batches to default pool. 1 new pipelines started.
```

### Template Data

The `data` field maps recipient addresses to variable maps. When rendering, EEx templates in `html` and `text` are compiled with the recipient's data:

```json
{
  "message": {
    "to": ["alice@example.com", "bob@example.com"],
    "html": "<p>Dear <%= @name %>,</p>",
    "data": {
      "alice@example.com": {"name": "Alice"},
      "bob@example.com": {"name": "Bob"}
    }
  }
}
```

## Pipeline Administration

### Get Cluster Statistics

```
GET /admin/pipelines
```

Returns pipeline distribution statistics across the cluster.

```json
{
  "total_pipelines": 5,
  "nodes": {
    "epoxi@10.0.0.1": 3,
    "epoxi@10.0.0.2": 2
  }
}
```

### Health Check All Pipelines

```
GET /admin/pipelines/health
```

Returns health status for all pipelines in the cluster.

### Health Check by Routing Key

```
GET /admin/pipelines/:routing_key
```

Returns health status for pipelines handling a specific routing key.

## DKIM Management

### Create DKIM Configuration

```
POST /admin/dkim
Content-Type: application/json
```

```json
{
  "tenant_id": "tenant1",
  "domain": "example.com",
  "selector": "dkim",
  "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----",
  "algorithm": "rsa-sha256",
  "canonicalization": "relaxed/relaxed"
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `tenant_id` | string | yes | Tenant identifier (alphanumeric, hyphens, underscores) |
| `domain` | string | yes | Domain to sign for |
| `selector` | string | yes | DKIM selector (max 63 chars) |
| `private_key` | string | yes | RSA private key in PEM format |
| `algorithm` | string | no | `"rsa-sha256"` (default) or `"rsa-sha1"` |
| `canonicalization` | string | no | Default: `"relaxed/relaxed"` |
| `status` | string | no | `"active"` (default) or `"inactive"` |

**Response:** `201 Created`

```json
{"success": true, "domain": "example.com"}
```

**Errors:**
- `400` -- Missing required fields or validation error
- `409` -- DKIM config already exists for this domain

### List All DKIM Configurations

```
GET /admin/dkim
```

Returns all DKIM configurations. Private keys are never included in responses.

```json
[
  {
    "tenant_id": "tenant1",
    "domain": "example.com",
    "selector": "dkim",
    "algorithm": "rsa-sha256",
    "canonicalization": "relaxed/relaxed",
    "status": "active",
    "created_at": "2025-01-15T10:30:00Z",
    "updated_at": "2025-01-15T10:30:00Z"
  }
]
```

### Get DKIM Configuration

```
GET /admin/dkim/:domain
```

Returns a single DKIM configuration (without private key).

**Errors:** `404` -- Domain not found

### Update DKIM Configuration

```
PUT /admin/dkim/:domain
Content-Type: application/json
```

```json
{
  "selector": "new-selector",
  "status": "inactive"
}
```

All fields are optional. Only provided fields are updated.

### Delete DKIM Configuration

```
DELETE /admin/dkim/:domain
```

**Response:** `200 OK`

```json
{"success": true, "domain": "example.com"}
```
