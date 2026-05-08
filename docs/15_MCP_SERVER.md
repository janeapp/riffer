# MCP Server

Riffer can **host** an MCP-compliant server that exposes registered `Riffer::Tool` subclasses to any [Model Context Protocol](https://modelcontextprotocol.io) client. This is the inverse of [`Riffer::Mcp`](14_MCP.md): instead of consuming third-party MCP servers as tool sources, `Riffer::McpServer` lets your application **be** an MCP server that other agents (e.g. Claude Code, Cursor, custom clients) can call into.

## Overview

1. Configure the server via `Riffer::McpServer.configure`: expose tools, set the bearer-token authenticator, optionally provide a per-request context builder.
2. Mount the resulting Rack app under any Rack-compatible server (Puma, Falcon).
3. Authenticated MCP clients call `tools/list` and `tools/call`; requests dispatch through the same `Riffer::Tool#call_with_validation` machinery used by `Riffer::Agent`.

## Configuration

```ruby
Riffer::McpServer.configure do |s|
  s.expose MyTool                               # default scope
  s.expose AdminTool, scope: :admin             # custom scope
  s.expose ReadOnlyTool, scope: [:default, :admin] # multi-scope

  s.authenticator = lambda do |bearer_token_string|
    JwtThing.verify(bearer_token_string) || nil # nil → 401
  end

  s.context_builder = lambda do |token_object|
    {tenant_id: token_object.tenant_id, user_id: token_object.user_id}
  end

  s.server_name = "my-app-mcp"      # optional; defaults to "riffer-mcp-server"
  s.server_version = "1.2.3"        # optional; defaults to "1.0.0"
end
```

`expose` accumulates across multiple `configure` calls. Re-exposing the same tool under a different scope keeps both records.

## Authentication

The `authenticator` is a `Proc` that receives the bearer token (the part after `Bearer ` in the `Authorization` header) as a `String` and must return either:

- An opaque **token object** (any object — typically a struct or model carrying tenant id, user id, scope) for valid tokens.
- `nil` (or raise) for invalid tokens — the middleware converts both to a JSON-RPC `401` response.

The token object is opaque to the server; it is only consumed by the `context_builder` you supply.

If `rack_app` is built without an authenticator configured, `Riffer::McpServer::ConfigurationError` is raised.

## Per-request context

The `context_builder` is a `Proc` that receives the resolved token object and returns a `Hash` to use as the per-request `context:` passed into every tool call. The default returns `{}`.

```ruby
s.context_builder = ->(token) { {tenant_id: token.tenant_id} }
```

Inside your tool's `#call(context:, **args)`, that hash is what you receive in `context:`.

## Mounting the Rack app

```ruby
# config.ru
require "riffer"

Riffer::McpServer.configure { |s| ... }

run Riffer::McpServer.rack_app
```

`Riffer::McpServer.rack_app` is memoized; subsequent calls return the same Rack app. Call `Riffer::McpServer.reset!` (test-only) to clear configuration, the registry, and the cached app.

The transport runs in **stateless** + **JSON-response** mode: each POST is independent, no session negotiation required. Clients simply send JSON-RPC `tools/list` / `tools/call` requests with `Content-Type: application/json` and `Accept: application/json`.

## Tool dispatch

Each registered `Riffer::Tool` subclass is wrapped in an `MCP::Tool` adapter. On a `tools/call`, the adapter:

1. Reads the per-request riffer context from the request's `server_context`.
2. Instantiates the tool and invokes `call_with_validation(context: ..., **args)` — applying the same parameter validation, timeout, and return-type guarantees as agent-loop dispatch.
3. Translates the result:
   - Success → `MCP::Tool::Response` with the tool's text content.
   - `Riffer::ValidationError`, `Riffer::TimeoutError`, or any `StandardError` → `MCP::Tool::Response` with `isError: true` and the message (no backtrace leak).

Dispatch deliberately **does not** route through `Riffer::ToolRuntime` — that runtime is for agent-loop exception conversion, whereas the MCP server *is* the outer loop and we want exceptions to surface at the HTTP boundary.

## Error Classes

| Class                                    | Raised when                                                                  |
| ---------------------------------------- | ---------------------------------------------------------------------------- |
| `Riffer::McpServer::Error`               | Base class for all server failures.                                          |
| `Riffer::McpServer::AuthenticationError` | Internal signal from the auth middleware (HTTP 401 is what the client sees). |
| `Riffer::McpServer::ConfigurationError`  | `rack_app` requested before `authenticator` was set.                         |

All inherit from `Riffer::McpServer::Error < Riffer::Error`.

## Requirements

`rack`, `puma`, and the `mcp` gem are **optional** development dependencies of riffer. To run the MCP server, add to your own Gemfile:

```ruby
gem "rack", "~> 3.0"
gem "puma", "~> 6.0"  # or falcon, etc.
gem "mcp", "~> 0.14"
```

If any gem is missing when `Riffer::McpServer.rack_app` is called, a `Riffer::Helpers::Dependencies::LoadError` is raised.

## Limitations

- **Single server per process.** Different consumers (e.g. internal vs external) get different scopes via `expose(..., scope:)`, not different servers.
- **No token storage or revocation.** The authenticator is a `Proc`; how it validates is the application's problem. Short-lived signed tokens are recommended.
- **Stateless only.** Sessions, server-to-client requests (`sampling/createMessage`, elicitation), and SSE streaming are not exposed in this release. Add them when a concrete need arises.
- **Tool results are text only.** Non-text MCP content types (images, embedded resources) are not surfaced.

## Relationship to `Riffer::Mcp`

`Riffer::Mcp` (client) and `Riffer::McpServer` (host) are **independent** namespaces — either can be used without the other. The client side discovers tools from third-party MCP servers; the server side exposes tools to MCP clients. They share neither registry nor configuration.
