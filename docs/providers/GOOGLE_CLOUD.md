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

With `credentials` unset, riffer resolves [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials) once per process with the `https://www.googleapis.com/auth/cloud-platform` scope: `GOOGLE_APPLICATION_CREDENTIALS`, then `gcloud auth application-default login`, then the attached service account on GCE, Cloud Run, and GKE.

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

The access token is cached on the credentials object and refreshed only when it is missing or about to expire. Concurrent fibers or threads that need a token at the same time wait for one shared refresh. This also avoids a `googleauth` bug on GCE, Cloud Run, and GKE, where concurrent fibers fetching a token from the metadata server raise `ThreadError` (surfacing as `Google::Auth::AuthorizationError` under load).

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

Gemini models behave as they do on the [Gemini provider](GEMINI.md): the same [model options](GEMINI.md#model-options) (`temperature`, `maxOutputTokens`, `topP`, `thinkingConfig`, `web_search`, ...), tool calling with [thought signatures](GEMINI.md#thought-signatures), and streaming.

```ruby
provider = Riffer::Providers::GoogleCloud.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "gemini-3.5-flash-lite"
)
puts response.content
```

The differences from the Gemini provider:

- **Structured output** is sent as `responseFormat`, which Agent Platform takes as a list: `[{text: {mimeType: "APPLICATION_JSON", schema: ...}}]`.
- **Web search** streams no `WebSearchStatus` events. Agent Platform doesn't return the search as separate parts, so the queries and sources only arrive in the `WebSearchDone` at the end. The `web_search` hash takes Agent Platform's `googleSearch` fields (for example `excludeDomains`).
- **Reasoning:** the agent-level [`reasoning`](../AGENTS.md#reasoning) setting uses the Gemini default, `thinkingConfig: {thinkingLevel: "<level>"}`. [Catalog](../CATALOG.md#reasoning) entries go under `google_cloud/...` keys; `gemini/...` entries don't apply.

Thought signatures are tagged `format: "google-cloud-generate-content-v1"` (`Riffer::Providers::GoogleCloud::REASONING_FORMAT`), not the Gemini provider's format: Agent Platform and the Gemini Developer API each reject the other's signatures. A conversation that moves between `gemini` and `google_cloud` keeps both kinds on its messages, and each provider sends back only its own. Switching between a tool call and its result still fails, since the call reaches the other API without a signature it accepts.

Files are sent inline as base64 (images and documents). A `FilePart.from_url` source works too: riffer downloads and base64-encodes it before sending, subject to the `allow_downloads` policy in [File Downloads](../CONFIGURATION.md#file-downloads).

## Claude Models (`anthropic_vertex`)

Claude models use Agent Platform's Anthropic endpoints (`rawPredict` and `streamRawPredict`), which take the Anthropic Messages API body. Riffer builds the same body as the [Anthropic provider](ANTHROPIC.md), so the same [model options](ANTHROPIC.md#model-options) apply (`max_tokens`, defaulting to `4096`, `thinking`, `output_config`, `web_search`, ...). The model goes in the URL, and `anthropic_version: "2026-10-21"`, the Anthropic provider's API version, goes in the body in place of the `anthropic-version` header. That version rejects `temperature`, `top_p` and `top_k`. Enable each Claude model for your project in Model Garden before calling it.

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

- **Tags stay off Gemini requests** - per-call [tags](../AGENTS.md#per-call-tags) reach spans only; they are not yet sent as Agent Platform request `labels`
- **No `gs://` file references** - files are always sent inline
- **Tool call IDs** - Gemini does not return unique call IDs for tool invocations; IDs are generated client-side
