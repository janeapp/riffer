# Configuration

Riffer uses a centralized configuration system for provider credentials and settings.

## Global Configuration

Use `Riffer.configure` to set up provider credentials:

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
  config.amazon_bedrock.region = 'us-east-1'
  config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end
```

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

For provider credentials and setup, see the individual [Provider guides](providers/).

### MCP (Model Context Protocol)

Optional settings for [MCP server integrations](14_MCP.md):

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

See [MCP](14_MCP.md) for registration, tags, and agent `use_mcp`.

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

Per-agent configuration overrides this global default. See [Advanced Tool Configuration — Tool Runtime](07_TOOL_ADVANCED.md#tool-runtime-experimental) for details.

### Skills

Skills-related global configuration lives under `config.skills`.

#### Default activation tool

Override the tool the LLM calls to activate a skill. Defaults to `Riffer::Skills::ActivateTool`:

```ruby
Riffer.configure do |config|
  config.skills.default_activate_tool = MyCustomActivateTool
end
```

Per-agent override is available inside the `skills` block via `activate_tool MyCustomActivateTool`. See [Skills — Custom Activation Tool](13_SKILLS.md#custom-activation-tool).

#### Default backend

Set an app-wide default skills backend. Used by any agent that declares a `skills` block without specifying its own `backend`:

```ruby
Riffer.configure do |config|
  config.skills.default_backend = Riffer::Skills::FilesystemBackend.new(".skills")
end
```

Accepts a `Riffer::Skills::Backend` instance or a `Proc` that receives `context` and returns a backend. Defaults to `nil` — agents that don't set their own backend get no skills, matching pre-existing behavior. Per-agent backends override this default.

### Tracing

Tracing-related global configuration lives under `config.tracing`. Riffer detects the OpenTelemetry API at runtime — without it (or without a host-configured OTEL SDK) every span is a silent no-op, and riffer carries no OTEL gem dependency either way.

```ruby
Riffer.configure do |config|
  config.tracing.enabled = ENV.fetch("RIFFER_TRACING_ENABLED", "true")
end
```

| Option             | Description                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`          | The kill switch, consulted on every span — flipping it at runtime takes effect immediately. Accepts booleans or `'true'`/`'false'`/`'1'`/`'0'`. Defaults to `true`.                                                                                                                                                                                                                                                                               |
| `capture_messages` | Opt-in capture of full message content on LLM-call spans (`gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`) as GenAI-semconv JSON. Defaults to `false` — message content routinely carries sensitive data. File attachments serialize as metadata-only stubs (media type and name, never bytes), and riffer applies no size limit of its own — cap oversized attributes with the OTEL SDK attribute length limits. |
| `tracer_provider`  | Explicit OTEL tracer provider (e.g. the SDK's in-memory provider in tests). Defaults to `nil`, which resolves the global `OpenTelemetry.tracer_provider` lazily at first span. Raises `Riffer::ArgumentError` if the `opentelemetry-api` gem isn't available at a supported version (>= 1.1, < 2).                                                                                                                                                |

Hosts own SDK and exporter wiring — riffer only emits spans through whatever provider the host configures. See [Tracing](16_TRACING.md) for the emitted span contract — names, attributes, hierarchy, and host wiring.

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

See [Messages — IDs](08_MESSAGES.md#ids) for more details.

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

There is no per-call override and no customizable placeholder. Callers needing finer control can call `agent.session.update(tool_call_id:, ...)` after the interrupt returns to upgrade a placeholder in place. See [Agent Lifecycle — Healing pending tool results on interrupt](04_AGENT_LIFECYCLE.md#healing-pending-tool-results-on-interrupt-experimental).

## Agent-Level Configuration

Override global configuration at the agent level:

### provider_options

Pass options directly to the provider client:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

  # Override API key for this agent only
  provider_options api_key: ENV['CUSTOM_OPENAI_KEY']
end
```

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

For different environments or use cases, use agent-level overrides:

```ruby
class ProductionAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  provider_options api_key: ENV['PRODUCTION_OPENAI_KEY']
end

class DevelopmentAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  provider_options api_key: ENV['DEV_OPENAI_KEY']
  model_options temperature: 0.0  # Deterministic for testing
end
```
