# Configuration

Riffer uses a centralized configuration system for provider credentials and settings.

## Global Configuration

Use `Riffer.configure` to set up provider credentials:

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
  config.openai.base_url = ENV['OPENAI_BASE_URL'] # Optional — gateways, proxies
  config.amazon_bedrock.region = 'us-east-1'
  config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end
```

Providers take no constructor arguments — these settings are the only way to give a provider its credentials.

## Accessing Configuration

Access the current configuration via `Riffer.config`:

```ruby
Riffer.config.openai.api_key
# => "sk-..."

Riffer.config.amazon_bedrock.region
# => "us-east-1"

Riffer.config.anthropic.api_key
# => "sk-ant-..."
```

## Provider-Specific Configuration

For provider credentials and setup, see the individual [Provider guides](providers/PROVIDERS.md).

### Provider Clients

Out of the box, each provider builds a default SDK client from its configured credentials. For anything beyond credentials — timeouts, retries, proxies, gateways — assign your own client to `config.<provider>.client`:

```ruby
Riffer.configure do |config|
  config.openai.client = OpenAI::Client.new(
    api_key: ENV['OPENAI_API_KEY'],
    timeout: 30,
    max_retries: 4
  )
  config.gemini.client = Riffer::Providers::Gemini::Client.new(
    api_key: ENV['GEMINI_API_KEY'],
    read_timeout: 120
  )
end
```

Every provider accepts a client instance or a `Proc` returning one:

| Provider       | Setting                        | Default client built from credentials                         |
| -------------- | ------------------------------ | ------------------------------------------------------------- |
| OpenAI         | `config.openai.client`         | `OpenAI::Client`                                              |
| Azure OpenAI   | `config.azure_openai.client`   | `OpenAI::Client` (with the Azure endpoint as `base_url`)      |
| Anthropic      | `config.anthropic.client`      | `Anthropic::Client`                                           |
| Amazon Bedrock | `config.amazon_bedrock.client` | `Aws::BedrockRuntime::Client`                                 |
| Gemini         | `config.gemini.client`         | `Riffer::Providers::Gemini::Client` (riffer-owned, see below) |
| OpenRouter     | `config.openrouter.client`     | `OpenAI::Client` (pinned to the OpenRouter endpoint)          |

A `Proc` takes **no arguments** and is resolved on **every LLM call**, never cached by riffer — memoize inside the Proc when construction is expensive. This makes the Proc the right tool for:

- **Fork safety** (Puma clustered, Sidekiq swarm): a client built at boot holds sockets that break across `fork`; build (and cache) per process instead.
- **Expiring credentials** (Azure AD tokens, STS-vended keys): re-resolve before they go stale.

```ruby
Riffer.configure do |config|
  # Fork-safe shared client: one per process, built on first use after fork.
  config.anthropic.client = -> {
    ClientRegistry.anthropic_for(Process.pid)
  }

  # Re-resolved before the token goes stale.
  config.azure_openai.client = -> {
    OpenAI::Client.new(api_key: AzureAd.current_token, base_url: ENV['AZURE_OPENAI_ENDPOINT'])
  }
end
```

Because the Proc receives no arguments, it can only vary the client by process-wide state — it cannot route per agent or per request. Client selection is a global concern; to talk to different accounts or endpoints from different agents, register a provider subclass with its own config (see [Multiple Configurations](#multiple-configurations)).

A configured client always wins over configured credentials: once `config.<provider>.client` is set, the credential members are unused, since riffer no longer builds the client.

### Falling through to the SDK

A credential you leave unset in riffer is omitted from the default client rather than passed as `nil`, so each vendor SDK still applies its own resolution. `OPENAI_API_KEY` / `OPENAI_BASE_URL`, `ANTHROPIC_API_KEY`, and the AWS region chain (`AWS_REGION`, shared config, IAM roles) all work with no riffer configuration at all.

Two providers deliberately opt out: `OpenRouter` and `AzureOpenAI` borrow `OpenAI::Client` to reach a **different** vendor, so they always pass their credential and endpoint explicitly. Falling through would let the OpenAI SDK pick up `OPENAI_API_KEY` / `OPENAI_BASE_URL` and send an OpenAI credential to `openrouter.ai` or your Azure endpoint. With nothing configured they raise instead — set `config.openrouter.api_key` / `OPENROUTER_API_KEY`, or `config.azure_openai.api_key` and `.endpoint` / `AZURE_OPENAI_API_KEY` and `AZURE_OPENAI_ENDPOINT`.

The Gemini provider has no vendor SDK, so riffer ships its own transport: `Riffer::Providers::Gemini::Client` exposes `base_url`, `open_timeout`, `read_timeout`, `write_timeout`, and `proxy_address`/`proxy_port`. Anything implementing its two-method contract (`post`, `post_stream`) can be assigned to `config.gemini.client` — see [Gemini](providers/GEMINI.md).

### MCP (Model Context Protocol)

Optional settings for [MCP server integrations](MCP.md):

| Option             | Description                                                                                                     |
| ------------------ | --------------------------------------------------------------------------------------------------------------- |
| `credentials`      | Optional `Proc` for per-run `tools/call` HTTP headers: `->(manifest:, matched_tags:, context:) { Hash or nil }` |
| `discovery_runner` | `Riffer::Runner` instance for tool discovery (default `Runner::Sequential.new`)                                 |

```ruby
Riffer.configure do |config|
  config.mcp.credentials = lambda do |manifest:, matched_tags:, context:|
    {"Authorization" => "Bearer #{token_for(context)}"}
  end
end
```

See [MCP](MCP.md) for registration, tags, and agent `use_mcp`.

### Tool Runtime (Experimental)

> **Warning:** This feature is experimental and may be removed or changed without warning in a future release.

Configure the default tool runtime for all agents:

```ruby
Riffer.configure do |config|
  config.tool_runtime = Riffer::Tools::Runtime::Threaded
end
```

| Value                             | Description                                                                                             |
| --------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `Riffer::Tools::Runtime` subclass | Instantiated automatically (e.g., `Riffer::Tools::Runtime::Inline`, `Riffer::Tools::Runtime::Threaded`) |
| `Riffer::Tools::Runtime` instance | Custom runtime with specific options                                                                    |
| `Proc`                            | Dynamic resolution                                                                                      |

Per-agent configuration overrides this global default. See [Advanced Tool Configuration — Tool Runtime](TOOL_ADVANCED.md#tool-runtime-experimental) for details.

### Skills

Skills-related global configuration lives under `config.skills`.

#### Default activation tool

Override the tool the LLM calls to activate a skill. Defaults to `Riffer::Skills::ActivateTool`:

```ruby
Riffer.configure do |config|
  config.skills.default_activate_tool = MyCustomActivateTool
end
```

Per-agent override is available inside the `skills` block via `activate_tool MyCustomActivateTool`. See [Skills — Custom Activation Tool](SKILLS.md#custom-activation-tool).

#### Default backend

Set an app-wide default skills backend. Used by any agent that declares a `skills` block without specifying its own `backend`:

```ruby
Riffer.configure do |config|
  config.skills.default_backend = Riffer::Skills::FilesystemBackend.new(".skills")
end
```

Accepts a `Riffer::Skills::Backend` instance or a `Proc` that receives `context` and returns a backend. Defaults to `nil` — agents that don't set their own backend get no skills, matching pre-existing behavior. Per-agent backends override this default.

### Tracing

Tracing-related global configuration lives under `config.tracing`. Riffer emits spans only through the backend you assign to `config.tracing.backend` — there is **no auto-detection**. OpenTelemetry is a built-in backend you opt into explicitly with `Riffer::Tracing::Otel.build`; with no backend set every span is a silent no-op, and riffer carries no OTEL gem dependency either way.

```ruby
Riffer.configure do |config|
  config.tracing.enabled = ENV.fetch("RIFFER_TRACING_ENABLED", "true")
  # Opt into OpenTelemetry (uses the global tracer provider):
  config.tracing.backend = Riffer::Tracing::Otel.build
end
```

| Option             | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `enabled`          | The kill switch, consulted on every span — flipping it at runtime takes effect immediately, short-circuiting to a no-op ahead of the backend. Accepts booleans or `'true'`/`'false'`/`'1'`/`'0'`. Defaults to `true`.                                                                                                                                                                                                                                                                                                                                              |
| `capture_messages` | Opt-in capture of full message content on LLM-call spans (`gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`) as GenAI-semconv JSON. Defaults to `false` — message content routinely carries sensitive data. File attachments serialize as metadata-only stubs (media type and name, never bytes), and riffer applies no size limit of its own — cap oversized attributes with the OTEL SDK attribute length limits.                                                                                                                  |
| `backend`          | The backend riffer routes spans through. Assign `Riffer::Tracing::Otel.build` (pass `provider:` to override the global tracer provider — e.g. an in-memory provider in tests), or any object satisfying the duck-typed contract (`in_span` / `current_context` / `with_context`) to route into a non-OTEL system (e.g. Datadog APM). Defaults to `nil` — a no-op. Raises `Riffer::ArgumentError` unless the value is `nil` or responds to `in_span`. See [Tracing → Routing to a non-OpenTelemetry backend](TRACING.md#routing-to-a-non-opentelemetry-backend). |

### Pricing

Configure per-model token prices and riffer computes the cost of each LLM call onto its [`TokenUsage`](MESSAGES.md#token-usage-semantics). Riffer ships **no** price table — so an unconfigured model simply carries no cost (`token_usage.cost` is `nil`).

```ruby
Riffer.configure do |config|
  # Rates are per million tokens, keyed by the same "provider/model" id you give the agent.
  config.pricing.set("anthropic/claude-sonnet-4-6", input: 3.0, output: 15.0, cache_read: 0.30, cache_write: 3.75)
  config.pricing.set("openai/gpt-4", input: 30.0, output: 60.0)

  # Pass an array to share one set of rates across a model family:
  config.pricing.set(["openai/gpt-4", "openai/gpt-4-0613"], input: 30.0, output: 60.0)
end
```

| Argument       | Description                                                                                                                                                                        |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `models`       | A `provider/model` id (e.g. `"openai/gpt-4"`) — the same string you pass to `model` — or an array of ids that share one set of rates. No alias matching; raises on a malformed id. |
| `input:`       | Price per **million** input tokens. Required. Applies to the uncached portion of `input_tokens`.                                                                                   |
| `output:`      | Price per **million** output tokens. Required.                                                                                                                                     |
| `cache_read:`  | Price per million cache-read tokens. Optional — when omitted, cache reads bill at the `input:` rate.                                                                               |
| `cache_write:` | Price per million cache-write tokens. Optional — when omitted, cache writes bill at the `input:` rate.                                                                             |

Because the cache buckets are subsets of `input_tokens`, the cost formula subtracts them before applying the input rate:

```text
cost = (input − cache_read − cache_write) × input_rate
     + cache_read  × cache_read_rate
     + cache_write × cache_write_rate
     + output      × output_rate
```

(all rates ÷ 1,000,000; an unset cache rate falls back to `input_rate`.) Cost is for observability, not billing — it's a `Float`, and sub-cent rounding can accumulate over a long run. See [Messages → Token Usage Semantics](MESSAGES.md#token-usage-semantics) for how cost surfaces and aggregates.

### Message ID Strategy

Opt in to stable identifiers on every message for logging, persistence, or replay:

```ruby
Riffer.configure do |config|
  config.message_id_strategy = :uuidv7
end
```

| Value             | Description                                                                      |
| ----------------- | -------------------------------------------------------------------------------- |
| `:none` (default) | No id is generated; `message.id` returns `nil` and `:id` is omitted from `to_h`. |
| `:uuid`           | UUIDv4 via `SecureRandom.uuid`.                                                  |
| `:uuidv7`         | Time-ordered UUIDv7 via `SecureRandom.uuid_v7` (Ruby 3.3+).                      |

When the strategy is not `:none`, every `Riffer::Messages::Base` instance — user prompts, system instructions, assistant responses, and tool results — gets an auto-generated `id` at construction time. IDs are included in `message.to_h` when present and omitted when `nil`. Provider API payloads are unaffected; the `id` stays on the Ruby side.

When constructing a `Riffer::Agent::Session` from persisted history with the strategy enabled, supply ids on every seeded message yourself — Riffer never fabricates identifiers for pre-existing history. Messages built via the `Riffer::Messages::*` constructors auto-generate ids per the strategy, so as long as those constructors are used at message-creation time, ids flow through.

See [Messages — IDs](MESSAGES.md#ids) for more details.

### Experimental: History Healing

> **Warning:** This feature is experimental and may change without notice.

Opts the agent into keeping the `tool_use` ↔ `tool_result` invariant intact on its own:

```ruby
Riffer.configure do |config|
  config.experimental_history_healing = true
end
```

When enabled, two repairs run automatically:

1. **Seeded session.** Passing a pre-populated `Riffer::Agent::Session` to `Agent.new(session: ...)` silently drops orphaned `tool_use` exchanges (assistant `tool_call` with no matching `Tool` result) and parentless `Tool` messages before the next inference call. Pending tool calls on the **resume boundary** — the last assistant whose tail is purely `Tool` results (or none) — are preserved; `execute_pending_tool_calls` runs them on the next LLM call.
2. **Interrupts.** Any orphan `tool_use` left when the loop is interrupted (caller-issued `interrupt!` or the built-in `INTERRUPT_MAX_STEPS` ceiling) is filled with a placeholder `Riffer::Messages::Tool` carrying `error_type: :interrupted` and the content `"Tool call interrupted before completion."`. Filled `call_id`s are exposed on `Riffer::Agent::Response#healed_tool_call_ids` (and `Riffer::StreamEvents::Interrupt#healed_tool_call_ids` when streaming).

Defaults to `false` — pre-healing behavior. Seeded sessions pass through untouched, and orphan `tool_use` left by an interrupt remain in history for `execute_pending_tool_calls` to re-run on the next call.

There is no per-call override and no customizable placeholder. Callers needing finer control can call `agent.session.update(tool_call_id:, ...)` after the interrupt returns to upgrade a placeholder in place. See [Agent Lifecycle — Healing pending tool results on interrupt](AGENT_LIFECYCLE.md#healing-pending-tool-results-on-interrupt-experimental).

## Agent-Level Configuration

Override global configuration at the agent level:

### model_options

Pass options to each LLM request:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

  # These options are sent with every generate/stream call
  model_options temperature: 0.7, reasoning: 'medium'
end
```

## Common Model Options

### OpenAI

| Option        | Description                                      |
| ------------- | ------------------------------------------------ |
| `temperature` | Sampling temperature (0.0-2.0)                   |
| `max_tokens`  | Maximum tokens in response                       |
| `top_p`       | Nucleus sampling parameter                       |
| `reasoning`   | Reasoning effort level (`low`, `medium`, `high`) |
| `web_search`  | Enable web search (`true` or config hash)        |

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  model_options temperature: 0.7, reasoning: 'medium'
end
```

### Amazon Bedrock

Options are passed through to the [Bedrock Converse API](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/BedrockRuntime/Client.html#converse-instance_method).

| Option                            | Description                                                      |
| --------------------------------- | ---------------------------------------------------------------- |
| `inference_config`                | Hash with `max_tokens`, `temperature`, `top_p`, `stop_sequences` |
| `additional_model_request_fields` | Hash for model-specific params (e.g., `top_k` for Claude)        |

```ruby
class MyAgent < Riffer::Agent
  model 'amazon_bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0'
  model_options inference_config: {temperature: 0.7, max_tokens: 4096}
end
```

### Anthropic

| Option        | Description                                 |
| ------------- | ------------------------------------------- |
| `temperature` | Sampling temperature                        |
| `max_tokens`  | Maximum tokens in response                  |
| `top_p`       | Nucleus sampling parameter                  |
| `top_k`       | Top-k sampling parameter                    |
| `thinking`    | Extended thinking config hash (Claude 3.7+) |
| `web_search`  | Enable web search (`true` or config hash)   |

```ruby
class MyAgent < Riffer::Agent
  model 'anthropic/claude-haiku-4-5-20251001'
  model_options temperature: 0.7, max_tokens: 4096
end

# With extended thinking (Claude 3.7+)
class ReasoningAgent < Riffer::Agent
  model 'anthropic/claude-haiku-4-5-20251001'
  model_options thinking: {type: "enabled", budget_tokens: 10000}
end
```

## Environment Variables

Recommended pattern for managing credentials:

```ruby
# config/initializers/riffer.rb (Rails)
# or at application startup

Riffer.configure do |config|
  config.openai.api_key = ENV.fetch('OPENAI_API_KEY') { raise 'OPENAI_API_KEY not set' }

  if ENV['BEDROCK_REGION']
    config.amazon_bedrock.region = ENV['BEDROCK_REGION']
    config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']
  end
end
```

## Multiple Configurations

Provider credentials and clients are **global**, resolved per process rather than per agent. For different environments, branch at boot:

```ruby
Riffer.configure do |config|
  config.openai.client = if Rails.env.production?
    OpenAI::Client.new(api_key: ENV['PRODUCTION_OPENAI_KEY'], max_retries: 4)
  else
    OpenAI::Client.new(api_key: ENV['DEV_OPENAI_KEY'], timeout: 10)
  end
end
```

Agents do not take per-agent credentials, and neither do providers — `Riffer::Providers::OpenAI.new` takes no arguments and reads everything from `config.openai`. When a single process genuinely has to reach two different accounts or endpoints, give the second one its own provider class and config, then register it under its own identifier:

```ruby
class InternalOpenAI < Riffer::Providers::OpenAI
  InternalConfig = Struct.new(:api_key, :base_url, :client)

  def self.config
    @config ||= InternalConfig.new(ENV['INTERNAL_OPENAI_KEY'], ENV['INTERNAL_GATEWAY'])
  end

  private

  def provider_config
    self.class.config
  end

  def build_client
    ::OpenAI::Client.new(api_key: provider_config.api_key, base_url: provider_config.base_url)
  end
end

Riffer::Providers::Repository.register(:internal_openai) { InternalOpenAI }
```

Agents then select it by model prefix (`model 'internal_openai/gpt-5-mini'`), and the two accounts never interfere. What _can_ vary per agent is the model and the generation parameters:

```ruby
class ProductionAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
end

class DevelopmentAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  model_options temperature: 0.0 # Deterministic for testing
end
```
