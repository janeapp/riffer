# Providers Overview

Providers are adapters that connect Riffer to LLM services. They implement a common interface for text generation and streaming.

## Available Providers

| Provider | Identifier | Gem Required |
|----------|------------|--------------|
| OpenAI | `openai` | `openai` |
| Amazon Bedrock | `amazon_bedrock` | `aws-sdk-bedrockruntime` |
| Test | `test` | None |

## Model String Format

Agents specify providers using the `provider/model` format:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'              # OpenAI
  model 'amazon_bedrock/anthropic.claude-3-sonnet-20240229-v1:0'  # Bedrock
  model 'test/any'                   # Test provider
end
```

## Provider Interface

All providers inherit from `Riffer::Providers::Base` and implement:

### generate_text

Generates a response synchronously:

```ruby
provider = Riffer::Providers::OpenAI.new(api_key: "...")

response = provider.generate_text(
  prompt: "Hello!",
  model: "gpt-4o"
)
# => Riffer::Messages::Assistant

# Or with messages
response = provider.generate_text(
  messages: [Riffer::Messages::User.new("Hello!")],
  model: "gpt-4o"
)
```

### stream_text

Streams a response as an Enumerator:

```ruby
provider.stream_text(prompt: "Tell me a story", model: "gpt-4o").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

## Method Parameters

| Parameter | Description |
|-----------|-------------|
| `prompt` | String prompt (required if `messages` not provided) |
| `system` | Optional system message string |
| `messages` | Array of message objects/hashes (alternative to `prompt`) |
| `model` | Model name string |
| `tools` | Array of Tool classes |
| `**options` | Provider-specific options |

You must provide either `prompt` or `messages`, but not both.

## Using Providers Directly

While agents abstract provider usage, you can use providers directly:

```ruby
require 'riffer'

Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end

provider = Riffer::Providers::OpenAI.new

# Simple prompt
response = provider.generate_text(
  prompt: "What is Ruby?",
  model: "gpt-4o"
)
puts response.content

# With system message
response = provider.generate_text(
  prompt: "Explain recursion",
  system: "You are a programming tutor. Use simple language.",
  model: "gpt-4o"
)

# With message history
messages = [
  Riffer::Messages::System.new("You are helpful."),
  Riffer::Messages::User.new("Hi!"),
  Riffer::Messages::Assistant.new("Hello!"),
  Riffer::Messages::User.new("How are you?")
]

response = provider.generate_text(
  messages: messages,
  model: "gpt-4o"
)
```

## Tool Support

Providers convert tools to their native format:

```ruby
class WeatherTool < Riffer::Tool
  description "Gets weather"
  params do
    required :city, String
  end
  def call(context:, city:)
    "Sunny in #{city}"
  end
end

response = provider.generate_text(
  prompt: "What's the weather in Tokyo?",
  model: "gpt-4o",
  tools: [WeatherTool]
)

if response.tool_calls.any?
  # Handle tool calls
end
```

## Provider Registry

Riffer uses a registry to find providers by identifier:

```ruby
Riffer::Providers::Repository.find(:openai)
# => Riffer::Providers::OpenAI

Riffer::Providers::Repository.find(:amazon_bedrock)
# => Riffer::Providers::AmazonBedrock

Riffer::Providers::Repository.find(:test)
# => Riffer::Providers::Test
```

## Provider-Specific Guides

- [OpenAI](02_OPENAI.md) - GPT models
- [Amazon Bedrock](03_AMAZON_BEDROCK.md) - Claude and other models via AWS
- [Test](04_TEST_PROVIDER.md) - Mock provider for testing
- [Custom Providers](05_CUSTOM_PROVIDERS.md) - Creating your own provider
