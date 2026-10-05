# Anthropic Provider

The Anthropic provider connects to Claude models via the Anthropic API.

## Installation

Add the Anthropic gem to your Gemfile:

```ruby
gem 'anthropic'
```

## Configuration

Configure your Anthropic API key:

```ruby
Riffer.configure do |config|
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end
```

For anything beyond the API key — timeouts, retries, proxies — supply your own `Anthropic::Client`:

```ruby
Riffer.configure do |config|
  config.anthropic.client = Anthropic::Client.new(
    api_key: ENV['ANTHROPIC_API_KEY'],
    timeout: 60
  )
end
```

The setting accepts a client instance or a no-argument `Proc`, resolved on every LLM call — see [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients).

## Supported Models

Use Anthropic model IDs in the `anthropic/model` format:

```ruby
model 'anthropic/claude-haiku-4-5-20251001'
model 'anthropic/claude-sonnet-4-5-20250929'
model 'anthropic/claude-opus-4-5-20251101'
```

## Model Options

### temperature

Controls randomness:

```ruby
model_options temperature: 0.7
```

### max_tokens

Maximum tokens in response:

```ruby
model_options max_tokens: 4096
```

### top_p

Nucleus sampling parameter:

```ruby
model_options top_p: 0.95
```

### top_k

Top-k sampling parameter:

```ruby
model_options top_k: 250
```

### thinking

Enable extended thinking (reasoning) for supported models. Pass the thinking configuration hash directly as Anthropic expects, or use the [`reasoning`](#reasoning-level) agent setting:

```ruby
# Adaptive thinking (Claude 4.6 and later)
model_options thinking: {type: "adaptive"}

# Budget tokens (Claude 4.5 and earlier; Claude 4.7 and later reject it)
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

## Reasoning level

The [`reasoning`](../CONFIGURATION.md#reasoning) agent setting maps to Claude's thinking fields. Claude 3.x and Claude 4.0, 4.1, and 4.5 (Sonnet, Opus, Haiku) get a token budget; every other model gets adaptive thinking with an effort:

| `reasoning` | Claude 4.5 and earlier                              | Later Claude and unknown models                                     |
| ----------- | --------------------------------------------------- | ------------------------------------------------------------------- |
| `:off`      | `thinking: {type: "disabled"}`                      | `thinking: {type: "disabled"}`                                      |
| `:low`      | `thinking: {type: "enabled", budget_tokens: 1024}`  | `thinking: {type: "adaptive"}`, `output_config: {effort: "low"}`    |
| `:medium`   | `thinking: {type: "enabled", budget_tokens: 8192}`  | `thinking: {type: "adaptive"}`, `output_config: {effort: "medium"}` |
| `:high`     | `thinking: {type: "enabled", budget_tokens: 24576}` | `thinking: {type: "adaptive"}`, `output_config: {effort: "high"}`   |

- With a token budget, `max_tokens` defaults to the budget plus 4096 instead of 4096. A `max_tokens` you set is kept.
- The effort is merged into `output_config`, alongside the structured output `format` and any other `output_config` keys you set.

Riffer sends these fields whatever the model. If the model doesn't support a value, the request fails with Anthropic's error. Setting `reasoning` together with `model_options thinking:`, or with `output_config: {effort:}` on an adaptive model, raises `Riffer::ArgumentError`.

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

### Reasoning Replay

Riffer sends the reasoning back to Anthropic on every later turn, as `thinking` and `redacted_thinking` blocks ahead of the message's text and `tool_use` blocks, in their original order and unchanged. For tool calls, sending it back is required: when thinking is enabled, Claude needs its earlier thinking blocks back to carry on after a tool result. You don't have to do anything; it happens as long as the assistant messages stay in the history.

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
