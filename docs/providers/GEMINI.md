# Gemini Provider

The Gemini provider connects to Google's Gemini models via the Gemini REST API.

## Configuration

Configure your Gemini API key:

```ruby
Riffer.configure do |config|
  config.gemini.api_key = ENV['GEMINI_API_KEY']
end
```

When `config.gemini.api_key` is unset, the provider reads `GEMINI_API_KEY`; with neither set it raises `Riffer::ArgumentError`. Set `config.gemini.base_url` to send requests somewhere other than `https://generativelanguage.googleapis.com` (proxies, regional mirrors).

## HTTP Client

Gemini has no vendor SDK, so riffer ships its own transport: `Riffer::Providers::Gemini::Client`, built on `Riffer::HTTP::Client`. The provider builds one from the configured credentials by default; construct your own to change timeouts, add retries or route through a proxy, and assign it to `config.gemini.client`:

```ruby
Riffer.configure do |config|
  config.gemini.client = Riffer::Providers::Gemini::Client.new(
    api_key: ENV['GEMINI_API_KEY'],
    connection: Faraday.new(request: { open_timeout: 10, read_timeout: 120 })
  )
end
```

| Option       | Default                                     | Description                                                    |
| ------------ | ------------------------------------------- | -------------------------------------------------------------- |
| `api_key`    | required                                    | Sent as the `x-goog-api-key` header                            |
| `base_url`   | `https://generativelanguage.googleapis.com` | API origin                                                     |
| `connection` | riffer default: 10s open / 600s read        | Your own `Faraday::Connection`; see [Connections][connections] |

Timeouts, retries, proxies and errors are covered in [Configuration → Connections][connections].

The setting accepts a client instance or a no-argument `Proc`, resolved on every LLM call — see [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients).

The class is a default implementation, not a required base: any object implementing the two-method contract works, e.g. an instrumented transport.

| Method                                  | Contract                                                                                                                         |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `post(path, body)`                      | POST `body` as JSON to `path`; return the parsed response `Hash` (symbol keys); raise `Riffer::APIError` on a non-success status |
| `post_stream(path, body) { \|chunk\| }` | POST `body` as JSON to `path`; yield raw response body chunks; raise `Riffer::APIError` on a non-success status                  |

[connections]: ../CONFIGURATION.md#connections

## Supported Models

Use Gemini model IDs in the `gemini/model` format:

```ruby
model 'gemini/gemini-3.5-flash-lite'
model 'gemini/gemini-3.8-flash'
model 'gemini/gemini-3.1-pro-preview'
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

### thinkingConfig

Controls thinking, passed through as Gemini expects:

```ruby
model_options thinkingConfig: {thinkingLevel: "low"}
```

The agent-level [`reasoning`](../AGENTS.md#reasoning) setting writes `thinkingConfig: {thinkingLevel: "<level>"}` by default, including `"off"` for `:off`, which Gemini rejects. Gemini 2.5 models take `thinkingBudget` instead; map them in a [catalog](../CATALOG.md#reasoning) entry.

### web_search

Enable grounding with Google Search. Pass `true` to use defaults or a hash to merge into the `googleSearch` tool:

```ruby
model_options web_search: true
model_options web_search: {timeRangeFilter: {startTime: "2026-01-01T00:00:00Z", endTime: "2026-06-30T00:00:00Z"}}
```

## Usage

### Basic Generation

```ruby
provider = Riffer::Providers::Gemini.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "gemini-3.5-flash-lite"
)
puts response.content
```

### Streaming

```ruby
provider.stream_text(prompt: "Tell me a story", model: "gemini-3.5-flash-lite").each do |event|
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
  model: "gemini-3.5-flash-lite",
  structured_output: structured_output
)
puts response.structured_output
```

Structured output is sent as `responseFormat`, which needs a gemini-3 model or later. gemini-2.x models ignore it and return prose.

The schema is sent in strict form: every field is listed as required, and an optional field is nullable, so the model can return `null` for a value it doesn't know instead of making one up. A `Hash` param needs a block and an `Array` param a block or `of:` (see [Structured Output Limitations](../AGENTS.md#limitations)).

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
  model: "gemini-3.5-flash-lite",
  tools: [WeatherTool]
)
```

Gemini's own call ids are short, so riffer gives each tool call its own `call_id` (`gemini_call_<hex>`) and appends Gemini's id when there is one. On later turns riffer sends that id back on the function call and its result, so Gemini can match results to parallel calls of the same tool.

### Thought Signatures

Gemini 3 models attach an opaque `thoughtSignature` to the first function call of each step, and to the last text part of an answer. A later request that sends a function call back without its signature is rejected with a 400.

Riffer keeps each signature on the assistant message as the `data` of an `:encrypted` [reasoning part](../MESSAGES.md#reasoning) tagged `format: "gemini-generate-content-v1"` (`Riffer::Providers::Gemini::REASONING_FORMAT`). A signature from a function call carries that tool call's `call_id` as its `id`; the text signature has no `id`. Streams emit them as `ReasoningDone` events. On later turns riffer puts each signature back on the part it came from. You don't have to do anything as long as the assistant messages stay in the history.

A function call that Gemini didn't sign, such as one another provider made before the conversation switched to Gemini, goes out with Gemini's placeholder signature (`skip_thought_signature_validator`), which Gemini accepts in place of a real one. That covers the first call of each step when that call has no signature for this provider. Google warns that a call without its real signature may degrade the model's answer, so if you persist sessions, keep the `reasoning` key when you store messages.

### Web Search

With `web_search` set, riffer adds the `googleSearch` tool and turns on `toolConfig.includeServerSideToolInvocations`, which Gemini requires when Google Search and function tools are used together.

```ruby
provider.stream_text(
  prompt: "What is the latest Ruby version?",
  model: "gemini-3.5-flash-lite",
  web_search: true
).each do |event|
  case event
  when Riffer::StreamEvents::WebSearchStatus
    puts "[search: #{event.status}] #{event.query}"
  when Riffer::StreamEvents::WebSearchDone
    puts "[search complete: #{event.query}]"
    event.sources.each { |s| puts "  - #{s[:title]}: #{s[:url]}" }
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

- Each search query streams as a `"searching"` `WebSearchStatus`; a `"completed"` status follows once the results are in.
- Gemini reports the queries and sources of a response together, at the end, without saying which query found which source. Riffer emits them as one `WebSearchDone`, after the text, with the queries joined by `", "`.
- Source `title`s are domains (`"ruby-lang.org"`) and `url`s are Google redirect links (`https://vertexaisearch.cloud.google.com/grounding-api-redirect/...`).
- The search parts of a response aren't sent back on later turns. After a tool call, Gemini searches again if it still needs results.

### File Support

Gemini's API only accepts inline base64-encoded files (images and documents), never a URL reference:

```ruby
file = Riffer::Messages::User::FilePart.new(data: base64_data, media_type: "image/png")
response = provider.generate_text(
  prompt: "Describe this image",
  model: "gemini-3.5-flash-lite",
  files: [file]
)
```

A `FilePart.from_url` source works too — riffer downloads and base64-encodes it before sending, subject to the `allow_downloads` policy in [File Downloads](../CONFIGURATION.md#file-downloads).

## Limitations

- **Tool call IDs** - Gemini does not return unique call IDs for tool invocations; IDs are generated client-side
