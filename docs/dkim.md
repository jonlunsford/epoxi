# DKIM Signing

Epoxi supports DomainKeys Identified Mail (DKIM) signing with per-domain, per-tenant configuration. Private keys are encrypted at rest using AES-256-GCM.

## Overview

When an email is rendered for delivery, `Epoxi.Render.dkim_for/1` checks the DKIM registry for an active configuration matching the sender's domain. If found, the email is signed during MIME encoding via `gen_smtp`'s `:mimemail.encode/2`.

The DKIM system has three layers:

| Module | Role |
|---|---|
| `Epoxi.DKIM.Config` | Validates and encrypts DKIM configurations |
| `Epoxi.DKIM.Registry` | ETS-backed fast lookup by domain |
| `Epoxi.DKIM.Manager` | High-level CRUD API, strips private keys from responses |

## Managing DKIM Configurations

### Via HTTP API

See [HTTP API - DKIM Management](http-api.md#dkim-management) for full endpoint documentation.

```bash
# Create
curl -X POST http://localhost:4000/admin/dkim \
  -H "Content-Type: application/json" \
  -d '{
    "tenant_id": "acme",
    "domain": "acme.com",
    "selector": "dkim",
    "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
  }'

# List
curl http://localhost:4000/admin/dkim

# Get
curl http://localhost:4000/admin/dkim/acme.com

# Update
curl -X PUT http://localhost:4000/admin/dkim/acme.com \
  -H "Content-Type: application/json" \
  -d '{"selector": "dkim2"}'

# Delete
curl -X DELETE http://localhost:4000/admin/dkim/acme.com
```

### Via Elixir API

```elixir
# Create
{:ok, config} = Epoxi.DKIM.Manager.create(%{
  tenant_id: "acme",
  domain: "acme.com",
  selector: "dkim",
  private_key: "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----",
  algorithm: "rsa-sha256",
  canonicalization: "relaxed/relaxed"
})

# Lookup
{:ok, public_info} = Epoxi.DKIM.Manager.get("acme.com")

# Update
{:ok, updated} = Epoxi.DKIM.Manager.update("acme.com", %{selector: "dkim2"})

# List all
configs = Epoxi.DKIM.Manager.list()

# List by tenant
{:ok, configs} = Epoxi.DKIM.Manager.list_by_tenant("acme")

# Remove
:ok = Epoxi.DKIM.Manager.remove("acme.com")
```

## Configuration Fields

| Field | Required | Default | Validation |
|---|---|---|---|
| `tenant_id` | yes | -- | Alphanumeric, hyphens, underscores |
| `domain` | yes | -- | Valid domain name, not an IP address |
| `selector` | yes | -- | Alphanumeric, dots, hyphens, underscores; max 63 chars |
| `private_key` | yes | -- | PEM-formatted RSA key (must have BEGIN/END markers) |
| `algorithm` | no | `"rsa-sha256"` | `"rsa-sha256"` or `"rsa-sha1"` |
| `canonicalization` | no | `"relaxed/relaxed"` | `"relaxed/relaxed"`, `"relaxed/simple"`, `"simple/relaxed"`, or `"simple/simple"` |
| `status` | no | `:active` | `:active` or `:inactive` |

## Encryption

Private keys are never stored in plaintext. The encryption flow:

1. A **master key** is read from `Application.get_env(:epoxi, :dkim_master_key)`.
2. A **tenant-specific key** is derived: `SHA-256(master_key <> tenant_id)`.
3. A random 16-byte **IV** is generated for each encryption.
4. The key is encrypted using **AES-256-GCM** with the derived key and IV.
5. The stored format is: `<<IV::16 bytes, Tag::16 bytes, Ciphertext::rest>>`.

This means:
- Each tenant's keys are encrypted with a unique derived key.
- The same plaintext key encrypted twice produces different ciphertext (random IV).
- Decryption requires both the master key and the correct tenant ID.

**Production requirement:** Set the `dkim_master_key` configuration to a secure value. See [Configuration](configuration.md#dkim-master-key).

## How Signing Works

During email rendering (`Epoxi.Render.encode/1`):

1. The sender's domain is extracted from the `from` address.
2. `Epoxi.DKIM.Registry.lookup/1` checks ETS for an active config for that domain.
3. If found, the private key is decrypted using `Epoxi.DKIM.Config.decrypt_private_key/1`.
4. DKIM options (selector, domain, private key) are passed to `:mimemail.encode/2`.
5. `gen_smtp` handles the actual DKIM header generation and signing.

If no DKIM configuration exists for the domain, or if decryption fails, the email is sent unsigned (a warning is logged on decryption failure).

## DNS Setup

After creating a DKIM configuration, publish the corresponding DNS TXT record:

```
<selector>._domainkey.<domain>  IN  TXT  "v=DKIM1; k=rsa; p=<base64-public-key>"
```

Example for selector `dkim` and domain `acme.com`:

```
dkim._domainkey.acme.com.  IN  TXT  "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA..."
```
