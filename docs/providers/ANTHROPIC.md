# Anthropic Provider

The Anthropic provider connects to Claude models via the Anthropic API.

## Configuration

Configure your Anthropic API key:

```ruby
Riffer.configure do |config|
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end
```

When `config.anthropic.api_key` is unset, the provider reads `ANTHROPIC_API_KEY`; with neither set it raises `Riffer::ArgumentError`. Set `config.anthropic.base_url` (or `ANTHROPIC_BASE_URL`) to send requests somewhere other than `https://api.anthropic.com`, such as a gateway or proxy.

Riffer reads no other `ANTHROPIC_*` variables. The anthropic gem also read `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_CUSTOM_HEADERS`; riffer does not. The key is already sent as `Authorization: Bearer`, and custom headers go in the client's `headers:` (see [HTTP Client](#http-client)).

## HTTP Client

The provider needs no Anthropic gem. Riffer ships its own Messages API transport, `Riffer::Providers::Anthropic::Client`, built on `Riffer::HTTP::Client`. The provider builds one from the configured credentials by default. To change timeouts, add retries or go through a proxy, build your own and assign it to `config.anthropic.client`:

```ruby
Riffer.configure do |config|
  config.anthropic.client = Riffer::Providers::Anthropic::Client.new(
    api_key: ENV['ANTHROPIC_API_KEY'],
    connection: Faraday.new(request: { open_timeout: 10, read_timeout: 120 })
  )
end
```

| Option       | Default                                | Description                                                         |
| ------------ | -------------------------------------- | ------------------------------------------------------------------- |
| `api_key`    | required                               | Sent as `Authorization: Bearer <api_key>`                           |
| `base_url`   | `https://api.anthropic.com`            | API origin; requests go to `<base_url>/v1/messages`                 |
| `headers`    | `{}`                                   | Sent on every request; replaces riffer's headers of the same name   |
| `connection` | Faraday defaults, 10s open / 600s read | Your own `Faraday::Connection`; see [Connections][connections]      |

Timeouts, retries, proxies, beta headers and errors are covered in [Configuration → Connections][connections]. An API error becomes a `Riffer::APIError` whose message carries the Anthropic error type, e.g. `Anthropic API error (401): authentication_error: Invalid bearer token`. No requests are retried unless your connection adds retries.

The `anthropic-version` header is pinned to `2026-10-21`. To send another version, pass it in `headers:`:

```ruby
Riffer::Providers::Anthropic::Client.new(
  api_key: ENV['ANTHROPIC_API_KEY'],
  headers: {'anthropic-version' => '2023-06-01'}
)
```

Version `2026-10-21` removed `temperature`, `top_p` and `top_k`; sending any of them returns a 400. Pin `2023-06-01` to keep using them. See Anthropic's [API versions](https://platform.claude.com/docs/en/api/versioning) for the other changes.

The setting accepts a client instance or a no-argument `Proc`, resolved on every LLM call — see [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients). An `Anthropic::Client` from the anthropic gem is not accepted and raises `Riffer::ArgumentError`.

[connections]: ../CONFIGURATION.md#connections

## Supported Models

Use Anthropic model IDs in the `anthropic/model` format:

```ruby
model 'anthropic/claude-haiku-4-5-20251001'
model 'anthropic/claude-sonnet-4-5-20250929'
model 'anthropic/claude-opus-4-5-20251101'
```

## Model Options

### max_tokens

Maximum tokens in response:

```ruby
model_options max_tokens: 4096
```

### thinking

Enable extended thinking (reasoning) for supported models. Pass the thinking configuration hash directly as Anthropic expects:

```ruby
# Enable with budget tokens
model_options thinking: {type: "enabled", budget_tokens: 10000}
```

### web_search

Enable server-side web search using Anthropic's `web_search_20250305` tool. Pass `true` to use defaults or a hash to merge with the tool definition:

```ruby
# Enable with defaults
model_options web_search: true

# With custom configuration
model_options web_search: {max_uses: 3}
```

## Example

```ruby
Riffer.configure do |config|
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end

class AssistantAgent < Riffer::Agent
  model 'anthropic/claude-haiku-4-5-20251001'
  instructions 'You are a helpful assistant.'
  model_options temperature: 0.7, max_tokens: 4096
end

agent = AssistantAgent.new
puts agent.generate("Explain quantum computing")
```

## Streaming

```ruby
agent.stream("Tell me about Claude models").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::TextDone
    puts "\n[Complete]"
  when Riffer::StreamEvents::ReasoningDelta
    print "[Thinking] #{event.content}"
  when Riffer::StreamEvents::ReasoningDone
    puts "\n[Thinking Complete]"
  when Riffer::StreamEvents::ToolCallDone
    puts "[Tool: #{event.name}]"
  end
end
```

## Tool Calling

Anthropic provider converts tools to the Anthropic tool format:

```ruby
class WeatherTool < Riffer::Tool
  description "Gets the current weather for a location"

  params do
    required :city, String, description: "The city name"
    optional :unit, String, description: "Temperature unit (celsius or fahrenheit)"
  end

  def call(context:, city:, unit: "celsius")
    # Implementation
    text("It's 22 degrees #{unit} in #{city}")
  end
end

class WeatherAgent < Riffer::Agent
  model 'anthropic/claude-haiku-4-5-20251001'
  uses_tools [WeatherTool]
end
```

## Extended Thinking

Extended thinking enables Claude to reason through complex problems before responding. This is available on supported models (Claude 3.7+).

```ruby
class ReasoningAgent < Riffer::Agent
  model 'anthropic/claude-haiku-4-5-20251001'
  model_options thinking: {type: "enabled", budget_tokens: 10000}
end
```

The agent-level [`reasoning`](../AGENTS.md#reasoning) setting defaults to adaptive thinking at the level's effort (`thinking: {type: "adaptive"}, output_config: {effort: "low"}`), and `:off` sends `thinking: {type: "disabled"}`. Claude 4.5 and earlier need a `budget_tokens` mapping in a [catalog](../CATALOG.md#reasoning) entry instead.

When streaming with extended thinking enabled, you'll receive `ReasoningDelta` events containing the model's thought process, followed by a `ReasoningDone` event when thinking completes:

```ruby
agent.stream("Solve this complex math problem").each do |event|
  case event
  when Riffer::StreamEvents::ReasoningDelta
    # Model's internal reasoning
    print "[Thinking] #{event.content}"
  when Riffer::StreamEvents::ReasoningDone
    puts "\n[Thinking complete]"
  when Riffer::StreamEvents::TextDelta
    # Final response
    print event.content
  end
end
```

The reasoning is kept on the assistant message as [reasoning parts](../MESSAGES.md#reasoning), whether you call `generate` or `stream`. Read it with `response.reasoning`, or as plain text with `reasoning_text` on the message. Each `thinking` block becomes a `:text` part carrying its `signature`, and each `redacted_thinking` block becomes an `:encrypted` part whose `data` is the block's opaque payload. `reasoning_text` leaves the redacted parts out, since they have no readable text. Every part is tagged `format: "anthropic-messages-v1"` (`Riffer::Providers::Anthropic::REASONING_FORMAT`).

A turn that used [web search](#web-search) also keeps its `server_tool_use` and `web_search_tool_result` blocks among the reasoning parts, in their place between the thinking blocks. Each becomes an `:encrypted` part whose `data` is the block's JSON, tagged `format: "anthropic-messages-server-tool-v1"` (`Riffer::Providers::Anthropic::SERVER_TOOL_FORMAT`). Claude signs a thinking block that follows a search over that search, so a later turn needs the blocks back where they were.

### Reasoning Replay

Riffer sends the reasoning back to Anthropic on every later turn, as `thinking`, `redacted_thinking` and web search blocks ahead of the message's text and `tool_use` blocks, in their original order and unchanged. For tool calls, sending it back is required: when thinking is enabled, Claude needs its earlier thinking blocks back to carry on after a tool result. You don't have to do anything; it happens as long as the assistant messages stay in the history.

If you persist sessions, keep the `reasoning` key when you store messages (see [Messages — Reasoning](../MESSAGES.md#reasoning)). If you drop it, later turns lose the model's earlier reasoning, and a tool-calling turn with thinking enabled may be rejected.

Only reasoning that this provider produced is sent back to Anthropic. A conversation that switches providers midway still works: reasoning from other providers (including OpenRouter's `anthropic-claude-v1` parts) is kept on the messages but left out of Anthropic requests.

## Web Search

Web search allows Claude to search the web for up-to-date information. When enabled, the provider injects the `web_search_20250305` server tool into the request.

```ruby
class SearchAgent < Riffer::Agent
  model 'anthropic/claude-haiku-4-5-20251001'
  model_options web_search: true
end

agent = SearchAgent.new
agent.stream("What happened in tech news today?").each do |event|
  case event
  when Riffer::StreamEvents::WebSearchStatus
    puts "[search: #{event.status}]"
    puts "  query: #{event.query}" if event.query
  when Riffer::StreamEvents::WebSearchDone
    puts "[search complete: #{event.query}]"
    event.sources.each { |s| puts "  - #{s[:title]}: #{s[:url]}" }
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

Anthropic emits sources with `title` and `url` on the `WebSearchDone` event.

The search blocks stay on the assistant message as reasoning parts and go back to Anthropic on later turns (see [Extended Thinking](#extended-thinking)), so Claude reuses the results instead of searching again.

## Message Format

The provider converts Riffer messages to Anthropic format:

| Riffer Message | Anthropic Format                                                |
| -------------- | --------------------------------------------------------------- |
| `System`       | Added to `system` array as `{type: "text", text: ...}`          |
| `User`         | `{role: "user", content: "..."}`                                |
| `Assistant`    | `{role: "assistant", content: [...]}` with text/tool_use blocks |
| `Tool`         | `{role: "user", content: [{type: "tool_result", ...}]}`         |

## Direct Provider Usage

```ruby
provider = Riffer::Providers::Anthropic.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "claude-haiku-4-5-20251001",
  temperature: 0.7
)

puts response.content
```

### With extended thinking:

```ruby
response = provider.generate_text(
  prompt: "Explain step by step how to solve a Rubik's cube",
  model: "claude-haiku-4-5-20251001",
  thinking: { type: "enabled", budget_tokens: 10000 }
)

puts response.content
```
