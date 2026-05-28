# OpenRouter Provider

The OpenRouter provider connects Riffer to [OpenRouter](https://openrouter.ai) — a unified gateway that exposes hundreds of LLMs from many vendors (Anthropic, OpenAI, Meta, Mistral, DeepSeek, Google, Grok, Qwen, and more) behind a single OpenAI-compatible Chat Completions endpoint.

OpenRouter is useful when you want one credential, one model-string format, and access to models Riffer doesn't have a direct provider for. It also offers built-in routing, fallback, and prompt transforms.

> **Note:** OpenRouter exposes only the OpenAI **Chat Completions** API, not the Responses API. That's why this provider does not subclass `Riffer::Providers::OpenAI` (which uses Responses). It implements the five hook methods independently against Chat Completions while still sharing the `openai` Ruby gem.

## Installation

Add the OpenAI gem to your Gemfile — OpenRouter reuses it:

```ruby
gem 'openai'
```

## Configuration

Set your API key globally:

```ruby
Riffer.configure do |config|
  config.openrouter.api_key = ENV['OPENROUTER_API_KEY']
end
```

Or per-agent:

```ruby
class MyAgent < Riffer::Agent
  model 'openrouter/anthropic/claude-sonnet-4.6'
  provider_options api_key: ENV['MY_OR_KEY']
end
```

The `api_key` resolves in order: keyword arg → `Riffer.config.openrouter.api_key` → `ENV['OPENROUTER_API_KEY']`.

## Supported Models

Use any OpenRouter model in the `openrouter/<openrouter-model-id>` format. The OpenRouter model ID is everything after the first slash:

```ruby
model 'openrouter/anthropic/claude-sonnet-4.6'
model 'openrouter/openai/gpt-4o-mini'
model 'openrouter/meta-llama/llama-3.1-70b-instruct'
model 'openrouter/deepseek/deepseek-r1'
model 'openrouter/mistralai/mixtral-8x22b-instruct'
```

See OpenRouter's [model catalog](https://openrouter.ai/models) for the full list.

## Model Options

### temperature, max_tokens, top_p, etc.

Standard sampling options pass through to the underlying model:

```ruby
model_options temperature: 0.5, max_tokens: 2048
```

### reasoning

For reasoning models (DeepSeek R1, OpenAI o-series via OpenRouter, etc.):

```ruby
model_options reasoning: 'high'  # 'low' | 'medium' | 'high'
```

Pass a hash for finer control:

```ruby
model_options reasoning: {effort: 'medium', max_tokens: 5000}
```

Streaming yields `Riffer::StreamEvents::ReasoningDelta` and `ReasoningDone` events when the model returns reasoning content.

### provider (routing preferences)

Pin which upstream provider OpenRouter should use, set allow/deny lists, or prefer a sort order:

```ruby
model_options provider: {
  order: ['anthropic', 'openai'],
  allow_fallbacks: false
}
```

See OpenRouter's [provider routing docs](https://openrouter.ai/docs/provider-routing) for the full schema.

### models (fallback chain)

If the primary model is unavailable, OpenRouter will try the next one in the list:

```ruby
model_options models: ['openai/gpt-4o', 'anthropic/claude-sonnet-4.6']
```

### transforms

Prompt transforms applied by OpenRouter (e.g. middle-out auto-truncation):

```ruby
model_options transforms: ['middle-out']
```

## Example

```ruby
Riffer.configure do |config|
  config.openrouter.api_key = ENV['OPENROUTER_API_KEY']
end

class TranslateAgent < Riffer::Agent
  model 'openrouter/anthropic/claude-sonnet-4.6'
  instructions 'You translate English to French.'
end

puts TranslateAgent.new.generate('Hello, world!')
```

## Streaming

```ruby
agent.stream('Explain Ruby blocks').each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::ReasoningDelta
    print "[thinking] #{event.content}"
  when Riffer::StreamEvents::TokenUsageDone
    puts "\n[tokens: #{event.token_usage.total_tokens}]"
  end
end
```

The provider opts into `stream_options: {include_usage: true}` automatically so `TokenUsageDone` fires reliably.

## Tool Calling

Tools are converted to OpenAI Chat Completions function format. The provider handles tool name encoding/decoding (slashes in tool names are wire-encoded with `__`) just like the OpenAI and Anthropic providers.

```ruby
class CalculatorTool < Riffer::Tool
  description 'Performs basic math'
  params do
    required :operation, String, enum: ['add', 'subtract', 'multiply', 'divide']
    required :a, Float
    required :b, Float
  end

  def call(context:, operation:, a:, b:)
    result = case operation
    when 'add' then a + b
    when 'subtract' then a - b
    when 'multiply' then a * b
    when 'divide' then a / b
    end
    text(result.to_s)
  end
end

class MathAgent < Riffer::Agent
  model 'openrouter/openai/gpt-4o-mini'
  uses_tools [CalculatorTool]
end
```

## Reasoning Models

Reasoning models surface their thought process via OpenRouter's normalised `reasoning` field. Enable it with the `reasoning` option:

```ruby
class ThinkAgent < Riffer::Agent
  model 'openrouter/deepseek/deepseek-r1'
  model_options reasoning: 'medium'
end

ThinkAgent.new.stream('What is 2+2? Think step by step.').each do |event|
  case event
  when Riffer::StreamEvents::ReasoningDelta
    print "[reasoning] #{event.content}"
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

## Routing & Fallbacks

Survive an upstream outage by chaining models:

```ruby
class ResilientAgent < Riffer::Agent
  model 'openrouter/openai/gpt-4o-mini'
  model_options models: [
    'openai/gpt-4o-mini',
    'anthropic/claude-haiku-4.5',
    'google/gemini-flash-1.5'
  ]
end
```

Pin to a specific upstream when consistency matters:

```ruby
model_options provider: {order: ['anthropic'], allow_fallbacks: false}
```

## Message Format

Riffer messages convert to Chat Completions roles:

| Riffer Message | Chat Completions Role |
| -------------- | --------------------- |
| `System`       | `system`              |
| `User`         | `user`                |
| `Assistant`    | `assistant`           |
| `Tool`         | `tool`                |

User messages with files become multi-part content (`image_url` for images, `file` for documents). Assistant tool calls go into a nested `tool_calls` array on the assistant message.

## Limitations (v1)

- **No unified web search.** OpenRouter doesn't expose a cross-vendor web-search tool — capability varies per upstream model.
- **Audio and image generation models** are not supported.
- **Responses API features** (e.g. OpenAI's `response.id` for continuation) are unavailable — OpenRouter implements only Chat Completions.

## Direct Provider Usage

```ruby
provider = Riffer::Providers::OpenRouter.new(api_key: ENV['OPENROUTER_API_KEY'])

response = provider.generate_text(
  prompt: 'Hello!',
  model: 'anthropic/claude-sonnet-4.6',
  temperature: 0.7
)

puts response.content
puts response.token_usage.total_tokens
```
