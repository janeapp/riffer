# Azure OpenAI Provider

The Azure OpenAI provider connects to OpenAI models hosted on Azure. It is a thin subclass of the OpenAI provider that configures the Azure-specific endpoint and API key — all request building, streaming, and extraction logic is inherited.

## Installation

Add the OpenAI gem to your Gemfile (same gem as the OpenAI provider):

```ruby
gem 'openai'
```

## Configuration

Credentials are resolved in order:

1. Global config (`Riffer.config.azure_openai.api_key` / `.endpoint`)
2. Environment variables (`AZURE_OPENAI_API_KEY` / `AZURE_OPENAI_ENDPOINT`)

### Global config

```ruby
Riffer.configure do |config|
  config.azure_openai.api_key = ENV['AZURE_OPENAI_API_KEY']
  config.azure_openai.endpoint = ENV['AZURE_OPENAI_ENDPOINT']
end
```

### Custom client

Azure AD token auth, timeouts, and retries are configured on your own `OpenAI::Client`. A `Proc` is the right shape for expiring AD tokens — it is resolved on every LLM call:

```ruby
Riffer.configure do |config|
  config.azure_openai.client = -> {
    OpenAI::Client.new(api_key: AzureAd.current_token, base_url: ENV['AZURE_OPENAI_ENDPOINT'])
  }
end
```

See [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients).

### Environment variables only

If `AZURE_OPENAI_API_KEY` and `AZURE_OPENAI_ENDPOINT` are set, no explicit configuration is needed:

```ruby
class MyAgent < Riffer::Agent
  model 'azure_openai/gpt-5-mini'
end
```

## Supported Models

Use any model deployed to your Azure OpenAI resource in the `azure_openai/model` format:

```ruby
model 'azure_openai/gpt-5.4'
model 'azure_openai/gpt-5-mini'
```

## Model Options

All model options from the OpenAI provider are supported:

### temperature

Controls randomness (0.0-2.0):

```ruby
model_options temperature: 0.7
```

### max_tokens

Maximum tokens in response:

```ruby
model_options max_tokens: 4096
```

### reasoning

Enables extended thinking (for supported models):

```ruby
model_options reasoning: 'medium'  # 'low', 'medium', or 'high'
```

### structured_output

Structured JSON output works identically to the OpenAI provider.

## Example

```ruby
Riffer.configure do |config|
  config.azure_openai.api_key = ENV['AZURE_OPENAI_API_KEY']
  config.azure_openai.endpoint = ENV['AZURE_OPENAI_ENDPOINT']
end

class SummaryAgent < Riffer::Agent
  model 'azure_openai/gpt-5-mini'
  instructions 'You are a summarization assistant. Be concise.'
  model_options temperature: 0.3
end

agent = SummaryAgent.new
puts agent.generate("Summarize the Ruby programming language in one paragraph.")
```

## Streaming

```ruby
agent.stream("Explain Ruby blocks").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

## Tool Calling

Tool calling works identically to the OpenAI provider:

```ruby
class CalculatorTool < Riffer::Tool
  description "Performs basic math operations"

  params do
    required :operation, String, enum: ["add", "subtract", "multiply", "divide"]
    required :a, Float, description: "First number"
    required :b, Float, description: "Second number"
  end

  def call(context:, operation:, a:, b:)
    result = case operation
    when "add" then a + b
    when "subtract" then a - b
    when "multiply" then a * b
    when "divide" then a / b
    end
    text(result.to_s)
  end
end

class MathAgent < Riffer::Agent
  model 'azure_openai/gpt-5-mini'
  uses_tools [CalculatorTool]
end
```

## Direct Provider Usage

```ruby
provider = Riffer::Providers::AzureOpenAI.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "gpt-5-mini",
  temperature: 0.7
)

puts response.content
```
