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
  config.tool_runtime = Riffer::ToolRuntime::Threaded
end
```

| Value                          | Description                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------- |
| `Riffer::ToolRuntime` subclass | Instantiated automatically (e.g., `Riffer::ToolRuntime::Inline`, `Riffer::ToolRuntime::Threaded`) |
| `Riffer::ToolRuntime` instance | Custom runtime with specific options                                                              |
| `Proc`                         | Dynamic resolution                                                                                |

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

Seeded messages passed to `agent.generate([...])` must carry their own `:id` when the strategy is enabled — Riffer never fabricates identifiers for pre-existing history:

```ruby
Riffer.configure { |c| c.message_id_strategy = :uuidv7 }

agent.generate([
  {role: :user, content: "Hi", id: "msg-001"},
  {role: :assistant, content: "Hello!", id: "msg-002"}
])
```

Missing ids raise `Riffer::ArgumentError` with the offending index.

See [Messages — IDs](08_MESSAGES.md#ids) for more details.

### Invalid Seed Strategy

Controls how `agent.generate(messages_array)` handles seeded history that violates the `tool_use` ↔ `tool_result` invariant — e.g. an assistant `tool_call` with no matching tool result deeper in history, or a `Riffer::Messages::Tool` whose `tool_call_id` has no parent assistant.

```ruby
Riffer.configure do |config|
  config.on_invalid_seed = :strip
end
```

| Value               | Description                                                                                                                                   |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `:ignore` (default) | Pass the seed through untouched. The pre-validation behavior — preserved as the default to avoid breaking existing callers.                   |
| `:raise`            | Raise `Riffer::ArgumentError` on the first violation, naming the offending `call_id`.                                                         |
| `:strip`            | Silently drop offending exchanges (orphaned `tool_use` + their siblings, parentless `Tool` messages) and proceed with the surviving messages. |

Pending tool calls on the **last** assistant message are not violations — riffer's cross-process resume path executes them via `execute_pending_tool_calls` before the next LLM call.

Per-call override:

```ruby
agent.generate(messages, on_invalid_seed: :strip)
agent.stream(messages, on_invalid_seed: :strip)
```

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
