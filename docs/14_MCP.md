# MCP

Riffer can consume third-party [Model Context Protocol](https://modelcontextprotocol.io) (MCP) servers as tool sources. Tools are discovered automatically at registration time — no handwritten Ruby per tool required.

## Overview

1. Register an MCP server globally with `Riffer::Mcp.register`.
2. Opt an agent into that server's tools using the `use_mcp` DSL.
3. The agent picks up the tools and calls them like any other Riffer tool.

## Registering a Server

```ruby
Riffer::Mcp.register(
  name: "github",        # unique identifier
  tags: [:github],       # agents opt-in by tag
  endpoint: "https://mcp.github.com",
  discovery_headers: -> { {"Authorization" => "Bearer #{ENV['GITHUB_TOKEN']}"} }
)
```

`register` blocks until tool discovery completes (or fails). Discovery uses the configured `Riffer::Runner` (default `Runner::Sequential` — inline). To run discovery on a pool thread (e.g. for Rails connection-pool isolation), set `config.mcp.discovery_runner = Riffer::Runner::Threaded.new`; `register` still blocks but the work runs off the calling thread.

### Discovery headers

`discovery_headers` is a Hash or Proc used **only** for MCP `tools/list` when the discovery client is built (the Proc runs once at that time). Use it for bootstrap identity: service account, env-based token, or `{}` if listing is unauthenticated.

Optional **`credentials_scope`** on the manifest documents whether you expect invocation headers to depend on tenant and/or user keys in the agent `context` (e.g. `:global`, `:tenant`, `:user`). It does **not** store tenant or user ids — only a hint for your app and docs. For multi-tenant apps, `:user` often means “user in tenant” and your `context` may include both tenant and user identifiers.

## Session credentials callback

When **`Riffer.config.mcp.credentials`** is set to a Proc, each MCP `tools/call` resolves HTTP headers through that callback instead of reusing `discovery_headers`.

**Signature:**

```ruby
Riffer.configure do |config|
  config.mcp.credentials = lambda do |manifest:, matched_tags:, context:|
    # when caller does not have an integration, return nil to omit this server's tools for this run
    # when server is unauthenticated or local, return {} to include this server's tools with no extra headers
    # when authorization headers are required, return Hash<String,String> headers
  end
end
```

- **`manifest`** — the server's `Riffer::Mcp::Manifest`.
- **`matched_tags`** — intersection of the agent's `use_mcp` tags and `manifest.tags` for this registration (unioned across multiple `use_mcp` lines).
- **`context`** — the same hash passed to `generate` / `stream` for this run.

**Resolve time:** The proc is invoked once per matching registration before tools are exposed to the model.

**Call time:** Authenticated tool wrappers invoke the proc again for each execution. If it returns `nil`, then `Riffer::Mcp::CredentialsDeniedError` is raised.

If **`credentials` is unset**, discovery and `tools/call` share one client built from `discovery_headers` (same behaviour as a single static token for both list and call).

## Tags

Tags are entirely up to your application; Riffer does not define a canonical vocabulary. Each server may declare multiple tags; an agent includes every registration that shares **any** tag passed to `use_mcp`.

When MCPs are registered, assign **stable bucket tags** so agent classes can opt in without listing every server name—for example `tags: [:connectors, :github]` with `use_mcp :connectors` for all enabled connectors, or `use_mcp :github` for that integration only.

Registrations are **global** (endpoint + tags); **tenant and user** access are enforced in your **`credentials`** proc and whatever you put in **`context`**, not by putting ids on the manifest.

## Opting an Agent In

```ruby
class ResearchAgent < Riffer::Agent
  model "openai/gpt-5-mini"
  instructions "You are a research assistant."

  use_mcp :github
end
```

By default, `use_mcp` uses **progressive discovery**. The agent receives `mcp_search` rather than every schema up front. See [Progressive Tool Discovery](#progressive-tool-discovery).

`use_mcp` accepts any tag registered via `Riffer::Mcp.register`. Multiple calls accumulate — the agent receives tools from all matching servers:

```ruby
class MultiAgent < Riffer::Agent
  model "openai/gpt-5-mini"

  use_mcp :github
  use_mcp :jira
end
```

MCP tools are appended after any tools declared with `uses_tools`.

Tool names must be unique across `uses_tools` and all included MCP servers; duplicate names raise `Riffer::ArgumentError` when tools are resolved.

### Subclassing

Like [`uses_tools`](03_AGENTS.md#uses_tools), **`use_mcp` is not inherited** from the superclass. Declare `use_mcp` on each agent class that should load MCP tools.

## Progressive Tool Discovery

Progressive discovery is the default. The `use_mcp` instruction exposes **`mcp_search`** instead of flooding the context with every tool schema up front.

```ruby
class ResearchAgent < Riffer::Agent
  model "openai/gpt-4o"

  use_mcp :github                        # default: tools discoverable on demand
  use_mcp :jira, progressive: false      # opt-out: all Jira tools injected directly
end
```

Only use `progressive: false` when the server has a small, stable set of tools you always want available.

**`mcp_search`** — Search for available tools by name or description.
- `query` (required, non-empty) — filter by name or description substring.

On a successful search, matching tools are injected into the agent's active tool list. The model calls them natively on the next turn — no proxy or JSON-encoded arguments.

**Example flow:**

1. Agent starts — only `mcp_search` appears in the tool list.
2. LLM calls `mcp_search` with `query: "create pull request"`.
3. Riffer injects `github__create_pr` into the active tool list and returns an acknowledgment.
4. LLM calls `github__create_pr` directly with its real schema (e.g. `title:`, `body:`, `base:`).
5. The provider validates the arguments; the tool executes with all credential handling intact.

Injected tools accumulate across turns — tools discovered in one search remain available for subsequent calls without re-searching.

**Multiple progressive `use_mcp` calls:** All matching registrations are combined into one `mcp_search`:

```ruby
use_mcp :connectors_a   # both default to progressive
use_mcp :connectors_b
# → one mcp_search exposing tools from both registrations
```

**Credential handling:** Progressive tools follow the same credential rules as regular tools — see [Session credentials callback](#session-credentials-callback).

**Tool access in tools:** The full discovery pool is available via `context[:mcp_progressive_tools]` and injected tools via `context[:injected_tools]` (both `Array[Riffer::Tool subclass]`). These keys are framework-managed — treat them as read-only from application code.

## Unregistering a Server

```ruby
Riffer::Mcp.unregister("github")
```

Subsequent agent runs will not include tools from that server. Call `register` again (with fresh `discovery_headers` if needed) to re-register.

## Introspection

```ruby
Riffer::Mcp.registrations
# => {"github" => #<Riffer::Mcp::Registration ...>, ...}

reg = Riffer::Mcp.registrations["github"]
reg.tools    # => [<Class:...>, ...]  (Riffer::Tool subclasses)
```

Discovery failures raise from `register` directly, typically `Faraday::Error` for network issues or `Riffer::DependencyError` if the `mcp`/`faraday` gems are missing. Rescue `StandardError` for graceful degradation:

```ruby
begin
  Riffer::Mcp.register(name: "github", ...)
rescue StandardError => e
  Rails.logger.warn("MCP registration failed: #{e.message}")
end
```

## Error Classes

| Class                                 | Raised when                                          |
| ------------------------------------- | ---------------------------------------------------- |
| `Riffer::Mcp::CredentialsDeniedError` | `credentials` proc returns `nil` during `tools/call` |

All inherit from `Riffer::Mcp::Error < Riffer::Error`.

## Limitations

- **Tool results:** `tools/call` responses are reduced to joined **text** content from MCP `content` items. Non-text parts (e.g. images, embedded resources) are not surfaced in this release.
- **Session credentials:** When `Riffer.config.mcp.credentials` is set, authenticated tool wrappers may build a **new HTTP client per tool invocation** so headers stay fresh; there is no connection pooling in this release.
- **Context window / progressive disclosure:** `use_mcp` defaults to progressive mode — tools are discovered via `mcp_search` and injected natively for subsequent calls. Use `progressive: false` to inject all schemas directly. See [Progressive Tool Discovery](#progressive-tool-discovery).

## Requirements

The `mcp` and `faraday` gems are **optional** dependencies — they are not included in Riffer's runtime gemspec. To use MCP integration, add both to your own Gemfile:

```ruby
gem "mcp"
gem "faraday"
```

Faraday is required for the MCP HTTP transport. If either gem is missing when `Riffer::Mcp.register` is called, a `Riffer::DependencyError` is raised.
