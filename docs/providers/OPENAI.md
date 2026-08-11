# OpenAI Provider

The OpenAI provider connects to OpenAI's API for GPT models.

## Installation

Add the OpenAI gem to your Gemfile:

```ruby
gem 'openai'
```

## Configuration

Set your API key globally:

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end
```

Both `api_key` and `base_url` resolve in order: constructor keyword arg → `Riffer.config.openai.*` → the OpenAI SDK's own `OPENAI_API_KEY` / `OPENAI_BASE_URL` lookup. Leaving one unset in riffer means the SDK resolves it, so an `OPENAI_BASE_URL` gateway is honored without any riffer configuration.

For anything beyond the API key — timeouts, retries, proxies — supply your own `OpenAI::Client`:

```ruby
Riffer.configure do |config|
  config.openai.client = OpenAI::Client.new(
    api_key: ENV['OPENAI_API_KEY'],
    timeout: 30,
    max_retries: 4
  )
end
```

The setting accepts a client instance or a no-argument `Proc`, resolved on every LLM call — see [Configuration → Provider Clients](../10_CONFIGURATION.md#provider-clients).

For OpenAI-compatible servers (LiteLLM, vLLM, corporate gateways), the constructor also accepts a `base_url`:

```ruby
provider = Riffer::Providers::OpenAI.new(api_key: ENV['GATEWAY_KEY'], base_url: 'http://localhost:4000/v1')
```

## Supported Models

Use any OpenAI model in the `openai/model` format:

```ruby
model 'openai/gpt-5.4'
model 'openai/gpt-5-mini'
```

## Model Options

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

When reasoning is enabled, you'll receive `ReasoningDelta` and `ReasoningDone` events during streaming.

### web_search

Enable server-side web search using OpenAI's `web_search_preview` tool. Pass `true` to use defaults or a hash to merge with the tool definition:

```ruby
# Enable with defaults
model_options web_search: true

# With custom configuration
model_options web_search: {search_context_size: "medium"}
```

## Example

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end

class CodeReviewAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are a code reviewer. Provide constructive feedback.'
  model_options temperature: 0.3, reasoning: 'medium'
end

agent = CodeReviewAgent.new
puts agent.generate("Review this code: def add(a,b); a+b; end")
```

## Streaming

```ruby
agent.stream("Explain Ruby blocks").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::ReasoningDelta
    # Extended thinking content
    print "[thinking] #{event.content}"
  when Riffer::StreamEvents::ReasoningDone
    puts "\n[reasoning complete]"
  end
end
```

## Tool Calling

OpenAI provider converts tools to function calling format with strict mode:

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
  model 'openai/gpt-5-mini'
  uses_tools [CalculatorTool]
end
```

## Web Search

Web search allows the model to search the web for up-to-date information. When enabled, the provider injects the `web_search_preview` tool into the request.

```ruby
class SearchAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  model_options web_search: true
end

agent = SearchAgent.new
agent.stream("What's the latest Ruby release?").each do |event|
  case event
  when Riffer::StreamEvents::WebSearchStatus
    # OpenAI emits a full status sequence:
    # "in_progress" → "searching" → "open_page" → "completed"
    puts "[search: #{event.status}]"
    puts "  query: #{event.query}" if event.query
    puts "  url: #{event.url}" if event.url
  when Riffer::StreamEvents::WebSearchDone
    puts "[search complete: #{event.query}]"
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

> **Note:** OpenAI sources include `url` but not `title`. Each source in the `sources` array will have `title: nil`.

## Message Format

The provider converts Riffer messages to OpenAI format:

| Riffer Message | OpenAI Role            |
| -------------- | ---------------------- |
| `System`       | `developer`            |
| `User`         | `user`                 |
| `Assistant`    | `assistant`            |
| `Tool`         | `function_call_output` |

## Direct Provider Usage

```ruby
provider = Riffer::Providers::OpenAI.new(api_key: ENV['OPENAI_API_KEY'])

response = provider.generate_text(
  prompt: "Hello!",
  model: "gpt-5-mini",
  temperature: 0.7
)

puts response.content
```
