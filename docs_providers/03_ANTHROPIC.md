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

Or per-agent:

```ruby
class MyAgent < Riffer::Agent
  model 'anthropic/claude-4-5-haiku-20251001'
  provider_options api_key: ENV['ANTHROPIC_API_KEY']
end
```

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

Enable extended thinking (reasoning) for supported models. Pass the thinking configuration hash directly as Anthropic expects:

```ruby
# Enable with budget tokens
model_options thinking: {type: "enabled", budget_tokens: 10000}
```

## Example

```ruby
Riffer.configure do |config|
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end

class AssistantAgent < Riffer::Agent
  model 'anthropic/claude-4-5-haiku-20251001'
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
    "It's 22 degrees #{unit} in #{city}"
  end
end

class WeatherAgent < Riffer::Agent
  model 'anthropic/claude-4-5-haiku-20251001'
  uses_tools [WeatherTool]
end
```

## Extended Thinking

Extended thinking enables Claude to reason through complex problems before responding. This is available on Claude 3.7 models.

```ruby
class ReasoningAgent < Riffer::Agent
  model 'anthropic/claude-4-5-haiku-20251001'
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
provider = Riffer::Providers::Anthropic.new(
  api_key: ENV['ANTHROPIC_API_KEY']
)

response = provider.generate_text(
  prompt: "Hello!",
  model: "claude-4-5-haiku-20251001",
  temperature: 0.7
)

puts response.content
```

### With extended thinking:

```ruby
response = provider.generate_text(
  prompt: "Explain step by step how to solve a Rubik's cube",
  model: "claude-4-5-haiku-20251001",
  thinking: { type: "enabled", budget_tokens: 10000 }
)

puts response.content
```
