# Google Cloud Provider

The Google Cloud provider connects to models hosted on Vertex AI (now the Gemini Enterprise Agent Platform), authenticating with Google Cloud credentials instead of an API key. It currently serves Gemini models.

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

| Setting       | Default                                 | Description                                                                 |
| ------------- | --------------------------------------- | --------------------------------------------------------------------------- |
| `project_id`  | `nil` (required)                        | The Google Cloud project that owns the Vertex AI quota and billing          |
| `location`    | `"global"`                              | The Vertex AI location requests are sent to; picks the endpoint (see below) |
| `credentials` | `nil` (Application Default Credentials) | A `googleauth` credentials object                                           |
| `client`      | `nil`                                   | A client instance or no-argument `Proc` (see [HTTP Client](#http-client))   |

`project_id` and `location` accept a `String` or `nil` and raise `Riffer::ArgumentError` naming the setting for anything else. Setting `location` to `nil` restores `"global"`.

### Credentials

With `credentials` unset, riffer resolves [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials) once per process with the `https://www.googleapis.com/auth/cloud-platform` scope: `GOOGLE_APPLICATION_CREDENTIALS`, then `gcloud auth application-default login`, then the attached service account on GCE, Cloud Run, and GKE.

To use a specific identity, pass any `googleauth` credentials object:

```ruby
Riffer.configure do |config|
  config.google_cloud.project_id = 'my-project'
  config.google_cloud.credentials = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(ENV.fetch('VERTEX_SERVICE_ACCOUNT_KEY')),
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

A single `location` applies to every `google_cloud/...` model. To bind one location explicitly, or to reach several locations from one process, use either approach below.

### Binding the client

`config.google_cloud.client` takes a client instance or a no-argument `Proc` resolved on every LLM call (see [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients)). A configured client wins over `project_id`, `location`, and `credentials`:

```ruby
Riffer.configure do |config|
  config.google_cloud.client = -> {
    Riffer::Providers::GoogleCloud::Client.new(
      project_id: 'my-project',
      location: 'europe-west4',
      read_timeout: 120
    )
  }
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

Agents then pick the location by model prefix (`model 'google_cloud_eu/gemini-2.5-flash'`). Register each subclass once, at boot, and return the same class from the block every time: riffer maps a provider class back to its registry key, and [pricing](../CONFIGURATION.md#pricing) looks rates up under that key (`google_cloud_eu/gemini-2.5-flash`).

## HTTP Client

Riffer ships its own Vertex transport, `Riffer::Providers::GoogleCloud::Client`. The provider builds one from the configured settings by default.

| Option          | Default                 | Description                                                    |
| --------------- | ----------------------- | -------------------------------------------------------------- |
| `project_id`    | required                | Project segment of the resource path                           |
| `location`      | required                | Location segment of the resource path; also picks the endpoint |
| `credentials`   | `nil`                   | A `googleauth` credentials object; `nil` resolves ADC          |
| `base_url`      | derived from `location` | API origin (Private Service Connect, proxies)                  |
| `open_timeout`  | `10`                    | Connection-open timeout in seconds                             |
| `read_timeout`  | `60`                    | Read timeout in seconds                                        |
| `write_timeout` | `nil`                   | Write timeout in seconds                                       |
| `proxy_address` | `nil`                   | HTTP proxy host                                                |
| `proxy_port`    | `nil`                   | HTTP proxy port                                                |

The class is a default implementation, not a required base: any object implementing the two-method contract works. Paths are relative to `v1/projects/{project_id}/locations/{location}/`.

| Method                                  | Contract                                                                                                                      |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `post(path, body)`                      | POST `body` as JSON to `path`; return the parsed response `Hash` (symbol keys); raise `Riffer::Error` on a non-success status |
| `post_stream(path, body) { \|chunk\| }` | POST `body` as JSON to `path`; yield raw response body chunks; raise `Riffer::Error` on a non-success status                  |

## Supported Models

Use Vertex AI model IDs in the `google_cloud/model` format:

```ruby
model 'google_cloud/gemini-2.5-flash'
model 'google_cloud/gemini-2.5-flash-lite'
model 'google_cloud/gemini-2.5-pro'
```

Model IDs may carry an `@version` suffix.

## Gemini Models

Vertex AI accepts the same request body as the Gemini Developer API, so Gemini models behave as they do on the [Gemini provider](GEMINI.md): the same [model options](GEMINI.md#model-options) (`temperature`, `maxOutputTokens`, `topP`, ...), structured output, tool calling, and streaming.

```ruby
provider = Riffer::Providers::GoogleCloud.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "gemini-2.5-flash"
)
puts response.content
```

Files are sent inline as base64 (images and documents). A `FilePart.from_url` source works too: riffer downloads and base64-encodes it before sending, subject to the `allow_downloads` policy in [File Downloads](../CONFIGURATION.md#file-downloads).

## Limitations

- **Tags stay off the request** - per-call [tags](../AGENTS.md#per-call-tags) reach spans only; they are not yet sent as Vertex AI request `labels`
- **No `gs://` file references** - files are always sent inline
- **No web search** - Google Search grounding is not exposed
- **Tool call IDs** - Gemini does not return unique call IDs for tool invocations; IDs are generated client-side
