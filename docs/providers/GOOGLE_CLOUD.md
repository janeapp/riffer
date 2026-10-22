# Google Cloud Providers

Two providers connect to models hosted on Gemini Enterprise Agent Platform (formerly Vertex AI), authenticating with Google Cloud credentials instead of an API key:

| Provider                             | Identifier         | Models |
| ------------------------------------ | ------------------ | ------ |
| `Riffer::Providers::GoogleCloud`     | `google_cloud`     | Gemini |
| `Riffer::Providers::AnthropicVertex` | `anthropic_vertex` | Claude |

Both read `config.google_cloud` and send requests through the same client, `Riffer::Providers::GoogleCloud::Client`.

## Installation

Add the `googleauth` gem to your Gemfile:

```ruby
gem 'googleauth'
```

## Configuration

```ruby
Riffer.configure do |config|
  config.google_cloud.project_id = 'my-project'
  config.google_cloud.location = 'us-central1' # Optional, defaults to "global"
end
```

| Setting       | Default                                 | Description                                                                      |
| ------------- | --------------------------------------- | -------------------------------------------------------------------------------- |
| `project_id`  | `nil` (required)                        | The Google Cloud project that owns the Agent Platform quota and billing          |
| `location`    | `"global"`                              | The Agent Platform location requests are sent to; picks the endpoint (see below) |
| `credentials` | `nil` (Application Default Credentials) | A `googleauth` credentials object                                                |
| `client`      | `nil`                                   | A client instance or no-argument `Proc` (see [HTTP Client](#http-client))        |

`project_id` and `location` accept a `String` or `nil` and raise `Riffer::ArgumentError` naming the setting for anything else. Setting `location` to `nil` restores `"global"`. Without a `project_id` (and no `client`), the first request raises `Riffer::ArgumentError`.

### Credentials

With `credentials` unset, riffer uses [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials). `googleauth` checks, in order:

1. The service account key file named by `GOOGLE_APPLICATION_CREDENTIALS`.
2. Your own Google account, after you run `gcloud auth application-default login` (local development).
3. The service account attached to the machine on Compute Engine, Cloud Run, or GKE.

To use a specific identity, pass any `googleauth` credentials object:

```ruby
Riffer.configure do |config|
  config.google_cloud.project_id = 'my-project'
  config.google_cloud.credentials = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(ENV.fetch('GOOGLE_CLOUD_SERVICE_ACCOUNT_KEY')),
    scope: Riffer::Providers::GoogleCloud::Client::SCOPE
  )
end
```

Riffer caches the access token and refreshes it shortly before it expires.

## Locations and Data Residency

The location decides the endpoint a request is sent to:

| `location`                     | Endpoint                                        |
| ------------------------------ | ----------------------------------------------- |
| `global`                       | `https://aiplatform.googleapis.com`             |
| `us`, `eu` (multi-region)      | `https://aiplatform.{us,eu}.rep.googleapis.com` |
| Any region, e.g. `us-central1` | `https://{location}-aiplatform.googleapis.com`  |

**The default `"global"` location offers no data-residency guarantee.** Google may serve a global request from any region. If your data must stay in a region or jurisdiction, set an explicit regional or multi-region `location`, and check that the model you use is available there.

A single `location` applies to every `google_cloud/...` and `anthropic_vertex/...` model. To bind one location explicitly, or to reach several locations from one process, use either approach below.

### Binding the client

`config.google_cloud.client` takes a client instance or a no-argument `Proc` resolved on every LLM call (see [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients)). Both providers use it, and it wins over `project_id`, `location`, and `credentials`:

```ruby
Riffer.configure do |config|
  config.google_cloud.client = Riffer::Providers::GoogleCloud::Client.new(
    project_id: 'my-project',
    location: 'europe-west4'
  )
end
```

### One provider per location

To route different agents to different locations, register a provider subclass per location. Riffer constructs providers with no arguments, so the location lives on the class:

```ruby
class GoogleCloudEurope < Riffer::Providers::GoogleCloud
  private

  # Ignore config.google_cloud.client, so this class always uses its own location.
  def global_client = nil

  def build_client
    Riffer::Providers::GoogleCloud::Client.new(
      project_id: Riffer.config.google_cloud.project_id,
      location: 'europe-west4',
      credentials: Riffer.config.google_cloud.credentials
    )
  end
end

Riffer::Providers::Repository.register(:google_cloud_eu) { GoogleCloudEurope }
```

A subclass of `Riffer::Providers::AnthropicVertex` binds a location for Claude models the same way.

Agents then pick the location by model prefix (`model 'google_cloud_eu/gemini-3.5-flash-lite'`). Register each subclass once, at boot, and return the same class from the block every time: riffer maps a provider class back to its registry key, and the [catalog](../CATALOG.md) looks up pricing and reasoning entries under that key (`google_cloud_eu/gemini-3.5-flash-lite`).

## HTTP Client

Riffer ships its own Agent Platform transport, `Riffer::Providers::GoogleCloud::Client`, built on `Riffer::HTTP::Client`. The provider builds one from the configured settings by default.

| Option        | Default                                | Description                                                    |
| ------------- | -------------------------------------- | -------------------------------------------------------------- |
| `project_id`  | required                               | Project segment of the resource path                           |
| `location`    | required                               | Location segment of the resource path; also picks the endpoint |
| `credentials` | `nil`                                  | A `googleauth` credentials object; `nil` resolves ADC          |
| `base_url`    | derived from `location`                | API origin (Private Service Connect, proxies)                  |
| `headers`     | `{}`                                   | Sent on every request; replaces riffer's same-name headers     |
| `connection`  | Faraday defaults, 10s open / 600s read | Your own `Faraday::Connection`; see [Connections][connections] |

Timeouts, retries, proxies and errors are covered in [Configuration → Connections][connections]. Errors are labelled `Google Cloud API error (<status>): <message>`.

The class is a default implementation, not a required base: any object implementing the two-method contract works. Paths are relative to `v1/projects/{project_id}/locations/{location}/`.

| Method                                  | Contract                                                                                                                         |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `post(path, body)`                      | POST `body` as JSON to `path`; return the parsed response `Hash` (symbol keys); raise `Riffer::APIError` on a non-success status |
| `post_stream(path, body) { \|chunk\| }` | POST `body` as JSON to `path`; yield raw response body chunks; raise `Riffer::APIError` on a non-success status                  |

[connections]: ../CONFIGURATION.md#connections

## Supported Models

Use Agent Platform model IDs, prefixed with the provider for the model family:

```ruby
model 'google_cloud/gemini-3.5-flash-lite'
model 'google_cloud/gemini-3.8-flash'
model 'anthropic_vertex/claude-haiku-5-5'
model 'anthropic_vertex/claude-haiku-4-5@20251001'
```

Model IDs may carry an `@version` suffix, as Agent Platform's dated Claude snapshots do; use the ID Model Garden shows.

## Gemini Models (`google_cloud`)

### Model Options

#### temperature

Controls randomness:

```ruby
model_options temperature: 0.7
```

#### maxOutputTokens

Maximum tokens in response:

```ruby
model_options maxOutputTokens: 4096
```

#### topP

Nucleus sampling:

```ruby
model_options topP: 0.9
```

#### thinkingConfig

Controls thinking, passed through as Agent Platform expects:

```ruby
model_options thinkingConfig: {thinkingLevel: "low"}
```

The agent-level [`reasoning`](../AGENTS.md#reasoning) setting writes `thinkingConfig: {thinkingLevel: "<level>"}` by default. To map a model differently, add a [catalog](../CATALOG.md#reasoning) entry under its `google_cloud/...` key.

#### web_search

Enable grounding with Google Search. Pass `true` to use defaults or a hash to merge into the `googleSearch` tool:

```ruby
model_options web_search: true
model_options web_search: {excludeDomains: ["example.com"]}
```

### Basic Generation

```ruby
provider = Riffer::Providers::GoogleCloud.new

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

Riffer gives each tool call its own `call_id` (`gemini_call_<hex>`) and appends the model's id when there is one. On later turns riffer sends that id back on the function call and its result, so the model can match results to parallel calls of the same tool.

### Thought Signatures

Gemini 3 models attach an opaque `thoughtSignature` to the first function call of each step, and to the last text part of an answer. A later request that sends a function call back without its signature is rejected with a 400.

Riffer keeps each signature on the assistant message as the `data` of an `:encrypted` [reasoning part](../MESSAGES.md#reasoning) tagged `format: "google-cloud-generate-content-v1"` (`Riffer::Providers::GoogleCloud::REASONING_FORMAT`). A signature from a function call carries that tool call's `call_id` as its `id`; the text signature has no `id`. Streams emit them as `ReasoningDone` events. On later turns riffer puts each signature back on the part it came from. You don't have to do anything as long as the assistant messages stay in the history.

If you persist sessions, keep the `reasoning` key when you store messages. If you drop it and pick a session back up between a tool call and its result, the next request is rejected. Only the signatures of the current turn are checked, so older turns without them still work.

### Web Search

With `web_search` set, riffer adds the `googleSearch` tool and turns on `toolConfig.includeServerSideToolInvocations`, which is required when Google Search and function tools are used together.

```ruby
provider.stream_text(
  prompt: "What is the latest Ruby version?",
  model: "gemini-3.5-flash-lite",
  web_search: true
).each do |event|
  case event
  when Riffer::StreamEvents::WebSearchDone
    puts "[search complete: #{event.query}]"
    event.sources.each { |s| puts "  - #{s[:title]}: #{s[:url]}" }
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

- No `WebSearchStatus` events are streamed. The queries and sources of a response arrive together, at the end, without saying which query found which source. Riffer emits them as one `WebSearchDone`, after the text, with the queries joined by `", "`.
- Source `title`s are domains (`"ruby-lang.org"`) and `url`s are Google redirect links (`https://vertexaisearch.cloud.google.com/grounding-api-redirect/...`).
- After a tool call, the model searches again if it still needs results.

### File Support

Files are sent inline as base64 (images and documents):

```ruby
file = Riffer::Messages::User::FilePart.new(data: base64_data, media_type: "image/png")
response = provider.generate_text(
  prompt: "Describe this image",
  model: "gemini-3.5-flash-lite",
  files: [file]
)
```

A `FilePart.from_url` source works too: riffer downloads and base64-encodes it before sending, subject to the `allow_downloads` policy in [File Downloads](../CONFIGURATION.md#file-downloads).

### Tags

Per-call [tags](../AGENTS.md#per-call-tags) are sent as request `labels`, which show up in Google Cloud billing reports. Riffer rewrites each tag into a valid label: downcased, any character other than a letter, digit, `_` or `-` replaced with `_`, and cut to 63 characters. Tags whose key doesn't start with a letter are dropped. `agent: "support/triage_agent"` goes out as `agent: "support_triage_agent"`.

To send fixed labels, set them as a model option; tags are merged over them:

```ruby
model_options labels: {cost_center: "cc_1234"}
```

## Claude Models (`anthropic_vertex`)

Claude models use Agent Platform's Anthropic endpoints (`rawPredict` and `streamRawPredict`), which take the Anthropic Messages API body. Riffer builds the same body as the [Anthropic provider](ANTHROPIC.md), so the same [model options](ANTHROPIC.md#model-options) apply (`max_tokens`, defaulting to `4096`, `temperature`, `thinking`, `output_config`, `web_search`, ...). The model goes in the URL, and `anthropic_version: "vertex-2023-10-16"` goes in the body in place of the `anthropic-version` header. Enable each Claude model for your project in Model Garden before calling it.

```ruby
provider = Riffer::Providers::AnthropicVertex.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "claude-haiku-5-5",
  thinking: { type: "adaptive", display: "summarized" },
  output_config: { effort: "high" }
)
```

Claude models on Agent Platform behave as they do on the Anthropic provider:

- **Reasoning** is captured as [reasoning parts](../MESSAGES.md#reasoning) tagged `format: "anthropic-messages-v1"` and sent back on later turns, as described in [Anthropic → Reasoning Replay](ANTHROPIC.md#reasoning-replay). Thinking signatures are accepted by both APIs, so a conversation can move between `anthropic` and `anthropic_vertex`. The agent-level [`reasoning`](../AGENTS.md#reasoning) setting uses the Anthropic default; [catalog](../CATALOG.md#reasoning) entries go under `anthropic_vertex/...` keys.
- **Web search:** `web_search: true` (or a hash of options) adds the `web_search_20250305` server tool and streams `WebSearchStatus` / `WebSearchDone` events.
- **Structured output** is sent as a strict `output_config.format` JSON schema.
- **Skills** are rendered with the XML skills adapter.
- **Tags:** only the reserved `user_id` tag is sent, as `metadata.user_id`.
- **Incomplete streams:** a stream that ends without a `message_stop` event raises `Riffer::IncompleteStreamError`.

`anthropic_vertex` never reads `config.anthropic` or `ANTHROPIC_API_KEY`. Files are sent inline as base64.

Web search and structured output are partner-model features that an organization policy can turn off. If a request fails with a `constraints/vertexai.allowedPartnerModelFeatures` violation, an organization policy administrator must allow `publishers/anthropic/models/MODEL:web_search` or `:structured_outputs` (or `publishers/anthropic` for every feature); see [Control access to Model Garden models](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/control-model-access).

## Limitations

- **No `gs://` file references** - files are always sent inline
- **Tool call IDs** - Gemini does not return unique call IDs for tool invocations; IDs are generated client-side
