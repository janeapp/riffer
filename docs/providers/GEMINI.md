# Gemini Provider

The Gemini provider connects to Google's Gemini models via the Gemini REST API.

## Configuration

Configure your Gemini API key:

```ruby
Riffer.configure do |config|
  config.gemini.api_key = ENV['GEMINI_API_KEY']
end
```

## HTTP Client

Gemini has no vendor SDK, so riffer ships its own transport: `Riffer::Providers::Gemini::Client`. The provider builds one from the configured `api_key` by default; construct your own to tune the HTTP knobs and assign it to `config.gemini.client`:

```ruby
Riffer.configure do |config|
  config.gemini.client = Riffer::Providers::Gemini::Client.new(
    api_key: ENV['GEMINI_API_KEY'],
    read_timeout: 120
  )
end
```

| Option          | Default                                     | Description                            |
| --------------- | ------------------------------------------- | -------------------------------------- |
| `api_key`       | `nil`                                       | Sent as the `x-goog-api-key` header    |
| `base_url`      | `https://generativelanguage.googleapis.com` | API origin (proxies, regional mirrors) |
| `open_timeout`  | `10`                                        | Connection-open timeout in seconds     |
| `read_timeout`  | `60`                                        | Read timeout in seconds                |
| `write_timeout` | `nil`                                       | Write timeout in seconds               |
| `proxy_address` | `nil`                                       | HTTP proxy host                        |
| `proxy_port`    | `nil`                                       | HTTP proxy port                        |

The setting accepts a client instance or a no-argument `Proc`, resolved on every LLM call — see [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients).

The class is a default implementation, not a required base: any object implementing the two-method contract works, e.g. a Faraday-based or instrumented transport.

| Method                                  | Contract                                                                                                                      |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `post(path, body)`                      | POST `body` as JSON to `path`; return the parsed response `Hash` (symbol keys); raise `Riffer::Error` on a non-success status |
| `post_stream(path, body) { \|chunk\| }` | POST `body` as JSON to `path`; yield raw response body chunks; raise `Riffer::Error` on a non-success status                  |

## Supported Models

Use Gemini model IDs in the `gemini/model` format:

```ruby
model 'gemini/gemini-2.5-flash-lite'
model 'gemini/gemini-2.5-pro'
model 'gemini/gemini-2.5-flash'
```

## Model Options

### temperature

Controls randomness:

```ruby
model_options temperature: 0.7
```

### maxOutputTokens

Maximum tokens in response:

```ruby
model_options maxOutputTokens: 4096
```

### topP

Nucleus sampling:

```ruby
model_options topP: 0.9
```

## Usage

### Basic Generation

```ruby
provider = Riffer::Providers::Gemini.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "gemini-2.5-flash-lite"
)
puts response.content
```

### Streaming

```ruby
provider.stream_text(prompt: "Tell me a story", model: "gemini-2.5-flash-lite").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::TextDone
    puts "\n---"
  end
end
```

### Structured Output

```ruby
params = Riffer::Params.new
params.required(:sentiment, String)
params.required(:score, Float)
structured_output = Riffer::Agent::StructuredOutput.new(params)

response = provider.generate_text(
  prompt: "Analyze: 'This is great!'",
  model: "gemini-2.5-flash-lite",
  structured_output: structured_output
)
puts response.structured_output
```

### Tool Calling

```ruby
class WeatherTool < Riffer::Tool
  description "Gets weather"
  params do
    required :city, String
  end
  def call(context:, city:)
    text("Sunny in #{city}")
  end
end

response = provider.generate_text(
  prompt: "What's the weather in Tokyo?",
  model: "gemini-2.5-flash-lite",
  tools: [WeatherTool]
)
```

### File Support

Gemini supports inline base64-encoded files (images and documents):

```ruby
file = Riffer::Messages::FilePart.new(data: base64_data, media_type: "image/png")
response = provider.generate_text(
  prompt: "Describe this image",
  model: "gemini-2.5-flash-lite",
  files: [file]
)
```

**Note:** URL-based file references are not supported. Provide base64-encoded data instead.

## Limitations

- **No web search** - Gemini's standard API does not include a web search tool
- **No URL files** - Only base64 inline data is supported for file attachments
- **Tool call IDs** - Gemini does not return unique call IDs for tool invocations; IDs are generated client-side
