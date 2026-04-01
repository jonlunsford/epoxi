# Email Rendering

Epoxi renders `%Epoxi.Email{}` structs into RFC 2045-compliant MIME messages using `gen_smtp`'s `:mimemail` module. The pipeline supports EEx template compilation, automatic content type detection, DKIM signing, and multi-part message construction.

## Rendering Pipeline

```
%Epoxi.Email{}
      │
      ▼
 EExCompiler.compile/1    ← Interpolate template variables into html/text
      │
      ▼
 Render.render/1          ← Build gen_smtp MIME tuple (type, subtype, headers, params, bodies)
      │
      ▼
 :mimemail.encode/2       ← Encode to RFC 2822 string, optionally DKIM-sign
      │
      ▼
 Binary (ready for SMTP DATA)
```

The entry point is `Epoxi.Render.encode/1`:

```elixir
encoded_message = Epoxi.Render.encode(email)
# => "From: Sender <sender@example.com>\r\nTo: ..."
```

An optional second argument specifies the compiler module (defaults to `Epoxi.EExCompiler`):

```elixir
Epoxi.Render.encode(email, MyCustomCompiler)
```

## EEx Templates

The `Epoxi.EExCompiler` compiles EEx syntax in the `html` and `text` fields of an email using the `data` field as assigns.

### Per-Recipient Data

When injecting via the HTTP API, the `data` field maps recipient addresses to variable maps. The `JSONDecoder` splits a multi-recipient message into individual `%Email{}` structs, each with its own data:

```json
{
  "message": {
    "from": "noreply@acme.com",
    "to": ["alice@example.com", "bob@example.com"],
    "subject": "Your invoice",
    "html": "<p>Hi <%= @name %>, your total is $<%= @amount %>.</p>",
    "text": "Hi <%= @name %>, your total is $<%= @amount %>.",
    "data": {
      "alice@example.com": {"name": "Alice", "amount": "42.00"},
      "bob@example.com": {"name": "Bob", "amount": "17.50"}
    }
  }
}
```

This produces two separate emails, each rendered with its own variables.

### Elixir API

When using the Elixir API directly, pass data as a keyword list:

```elixir
email = %Epoxi.Email{
  from: "noreply@acme.com",
  to: ["alice@example.com"],
  subject: "Welcome",
  html: "<h1>Hello, <%= @name %>!</h1>",
  text: "Hello, <%= @name %>!",
  data: [name: "Alice"]
}
```

If `data` is an empty map (`%{}`), template compilation is skipped and the raw `html`/`text` bodies are used as-is.

### Custom Compilers

Any module that implements `compile(%Epoxi.Email{}) :: %Epoxi.Email{}` can be used as a compiler. The compiler receives the full email struct and must return it with the `html` and `text` fields populated with final content.

## Content Type Detection

`Epoxi.Email.put_content_type/1` automatically determines the MIME content type based on which body fields are populated:

| `html` | `text` | Result |
|---|---|---|
| present | `""` | `text/html` |
| `""` | present | `text/plain` |
| present | present | `multipart/mixed` |
| other | other | `multipart/alternative` |

This is called automatically during rendering and during direct sends via `SmtpClient`.

## MIME Structure

`Epoxi.Render.render/1` builds a gen_smtp MIME tuple:

```elixir
{type, subtype, headers, parameters, bodies}
```

### Headers

Standard headers are built from email fields:

| Email Field | Header |
|---|---|
| `from` | `From` |
| `to` | `To` |
| `subject` | `Subject` |
| `reply_to` | `reply-to` |
| `cc` | `Cc` |
| `bcc` | `Bcc` |
| `headers` | Additional custom headers (map of atom keys to string values) |

Empty or nil header values are filtered out. Address fields (`from`, `to`, `cc`, `bcc`) are normalized to `"Name <address>"` format by `Epoxi.Parsing.normalize_addresses/1`:

- `"alice@example.com"` becomes `"Alice <alice@example.com>"`
- `"Alice <alice@example.com>"` is left unchanged
- The name is derived by capitalizing the local part and splitting on non-word characters

### Parameters

All parts use these default encoding parameters:

```elixir
%{
  "transfer-encoding": "quoted-printable",
  "content-type-params": [],
  disposition: "inline",
  "disposition-params": []
}
```

### Body Parts

For `multipart/mixed` and `multipart/alternative` content types, both plain text and HTML body parts are included. Each body part is a nested MIME tuple:

```elixir
{"text", "plain", [{"Content-type", "text/plain"}], params, email.text}
{"text", "html",  [{"Content-type", "text/html"}],  params, email.html}
```

## DKIM Integration

During encoding, `Epoxi.Render.dkim_for/1` looks up the sender's domain in the DKIM registry. If an active configuration is found and the private key decrypts successfully, DKIM options are passed to `:mimemail.encode/2`:

```elixir
[s: "dkim", d: "acme.com", private_key: "-----BEGIN RSA PRIVATE KEY-----\n..."]
```

If no configuration is found or decryption fails, an empty list is passed and the email is sent unsigned. See [DKIM Signing](dkim.md) for configuration details.

## Address Parsing

`Epoxi.Parsing` provides utilities used throughout the rendering and routing system:

### `get_hostname/1`

Extracts the domain from an email address, handling multiple formats:

```elixir
Epoxi.Parsing.get_hostname("alice@example.com")
# => "example.com"

Epoxi.Parsing.get_hostname("Alice <alice@example.com>")
# => "example.com"

Epoxi.Parsing.get_hostname(["alice@example.com"])
# => "example.com"
```

### `normalize_addresses/1`

Converts addresses to `"Name <address>"` format:

```elixir
Epoxi.Parsing.normalize_addresses(["foo@test.com", "bar@test.com"])
# => ["Foo <foo@test.com>", "Bar <bar@test.com>"]

Epoxi.Parsing.normalize_addresses(["Alice <alice@test.com>"])
# => ["Alice <alice@test.com>"]
```

## JSON Decoding

`Epoxi.JSONDecoder` converts JSON payloads into `%Epoxi.Email{}` structs. A single message with multiple `to` recipients is expanded into one struct per recipient, each with its own `data`:

```elixir
# Input: JSON with to: ["a@x.com", "b@x.com"]
# Output: [%Email{to: ["a@x.com"], data: ...}, %Email{to: ["b@x.com"], data: ...}]
emails = Epoxi.JSONDecoder.decode(json_string)
```

The decoder accepts both raw JSON strings and pre-decoded maps. Keys are atomized recursively via `Epoxi.Utils.atomize_keys/1`.
