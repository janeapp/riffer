# Metrics

Riffer can record [OpenTelemetry](https://opentelemetry.io/) metric instruments alongside its [spans](16_TRACING.md), following the [GenAI semantic conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/). Metric names, instrument types, units, and attributes are a public, versioned contract you can build dashboards and alerts against. This page is the reference for that contract.

As with tracing, Riffer only _records_ instruments. The host application owns the OpenTelemetry SDK, the metric reader, the exporter, and the aggregation — the standard OTEL split. Without a host SDK, every measurement is a silent no-op and Riffer carries no OpenTelemetry gem dependency.

> **OpenTelemetry metrics for Ruby is still pre-1.0.** The metrics API and SDK ship as separate, experimental gems (`opentelemetry-metrics-api`, `opentelemetry-metrics-sdk`) from the stable 1.x traces API. Riffer guards against an incompatible API and falls back to a no-op outside the supported range, but expect the host-side wiring below to evolve with those gems.

## Enabling metrics

Add the OpenTelemetry metrics SDK to your host application and register a metric reader with an exporter. Riffer detects the metrics API at runtime and starts recording through whatever meter provider the SDK configures.

```ruby
# Gemfile
gem "opentelemetry-metrics-sdk"
```

```ruby
require "opentelemetry-metrics-sdk"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "my-agent-host"
end
```

The metrics SDK is **separate** from the traces SDK (`opentelemetry-sdk`); add it explicitly even if you already trace. Any backend implementing the OpenTelemetry Metrics API ingests Riffer's instruments. For real reader and exporter setup (OTLP, periodic export, Views), see the [OpenTelemetry Ruby docs](https://opentelemetry.io/docs/languages/ruby/).

The two metrics knobs — the `enabled` kill switch and an explicit meter provider for tests — live in [Configuration — Metrics](10_CONFIGURATION.md#metrics). They are **independent** of the tracing knobs: you can run tracing while metrics are off, or the reverse.

Instruments are recorded under the instrumentation scope named `riffer`, versioned with the Riffer gem version — the runtime signal for which release produced a measurement; see [Stability](#stability).

### Bucket boundaries

Histogram bucket boundaries are a **host-side** concern. The OpenTelemetry metrics API does not let an instrumenting library attach bucket boundaries at instrument creation, so Riffer does not set them — the SDK's default buckets apply unless you override them. To match the GenAI semantic conventions' recommended boundaries (or your own), register a [View](https://opentelemetry.io/docs/specs/otel/metrics/sdk/#view) on the meter provider that targets the instrument by name and sets explicit bucket boundaries.

The convention recommends boundaries scaled to each instrument, so register one View per histogram — the token-count buckets below are for `gen_ai.client.token.usage`; `gen_ai.client.operation.duration` wants its own latency-scaled set, and `riffer.gen_ai.cost` a USD-scaled one.

```ruby
require "opentelemetry-metrics-sdk"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "my-agent-host"
end

# The GenAI semconv's recommended token-count boundaries. Register the View
# before Riffer records its first measurement.
OpenTelemetry.meter_provider.add_view(
  "gen_ai.client.token.usage",
  aggregation: OpenTelemetry::SDK::Metrics::Aggregation::ExplicitBucketHistogram.new(
    boundaries: [1, 4, 16, 64, 256, 1024, 4096, 16384, 65536, 262144, 1048576, 4194304, 16777216, 67108864]
  )
)
```

## Instruments

Each instrument is documented here as a row carrying its name, instrument type, unit, and attribute set.

### `gen_ai.client.operation.duration`

Histogram, unit `s`. The latency of a single GenAI operation, recorded around the same wrap as the matching [span](16_TRACING.md) on both the success and error paths and timed with a monotonic clock. Recording is independent of tracing — the metric fires even with `config.tracing.enabled = false`. Tell the three operations apart by `gen_ai.operation.name`.

| `gen_ai.operation.name` | Recorded around                                    | Attributes                                                                                                            |
| ----------------------- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `chat`                  | each provider call (`generate_text`/`stream_text`) | `gen_ai.operation.name`, `gen_ai.provider.name`, `gen_ai.request.model` (when set), `error.type` (on error)           |
| `invoke_agent`          | each agent run (`generate`/`stream`)               | `gen_ai.operation.name`, `gen_ai.provider.name`, `gen_ai.request.model`, `gen_ai.agent.name`, `error.type` (on error) |
| `execute_tool`          | each tool call                                     | `gen_ai.operation.name`, `gen_ai.tool.name`, `error.type` (on error)                                                  |

`error.type` carries the exception class for a raised error; for `execute_tool` it carries the handled error category (e.g. `validation_error`, `timeout_error`) when a tool returns an error result instead of raising — matching the span. `gen_ai.response.model` is not recorded yet; it will land once it is also captured on the chat span.

> **Streamed operations are consumption-paced.** A streamed `chat` or `invoke_agent` records its duration when the stream drains, so the value includes the time your consumer takes to iterate the events, not just provider latency. The matching span behaves the same way.

> **`gen_ai.tool.name` cardinality.** One time series exists per distinct tool name. With a large or dynamic tool set (for example MCP-discovered tools) that can grow unbounded — drop the attribute with a [View](https://opentelemetry.io/docs/specs/otel/metrics/sdk/#view) if your backend strains.

### `gen_ai.client.token.usage`

Histogram, unit `{token}`. Token volume for a single `chat` call, recorded from the normalized token usage after the provider responds. Each call emits **two data points** — one `input`, one `output` — distinguished by `gen_ai.token.type`. Recording is independent of tracing (it fires with `config.tracing.enabled = false`); for a streamed call it fires when the stream drains. `gen_ai.response.model` is not recorded yet, for the same reason as `operation.duration`.

| `gen_ai.token.type` | Value                                                 | Attributes                                                                                                              |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `input`             | total prompt tokens for the call, **cache-inclusive** | `gen_ai.operation.name` (always `chat`), `gen_ai.provider.name`, `gen_ai.token.type`, `gen_ai.request.model` (when set) |
| `output`            | tokens generated, including reasoning/thinking tokens | same                                                                                                                    |

> **Per-call only.** Token usage is never recorded at the run (`invoke_agent`) level. Metrics pre-aggregate, so emitting both the per-call points and a run total would double-count — sum the per-call points in your backend if you want a run total. This is the metric-side counterpart of the span-level [double-count trap](16_TRACING.md#token-usage-and-cost).

> **Cache buckets stay on spans.** The semconv `gen_ai.token.type` defines only `input` and `output`, so the prompt-cache subsets (`cache_read` / `cache_creation`) live on [spans](16_TRACING.md#token-usage-and-cost), not this metric. The `input` value is the cache-inclusive total, matching the span's `gen_ai.usage.input_tokens`.

A call that reports no usage records no data points, and a failed call has nothing to count — so this metric carries no `error.type` (the semconv marks it not applicable here, unlike `operation.duration`).

### `riffer.gen_ai.cost`

Histogram, unit `USD`. The cost of a single `chat` call, recorded from the [cost](16_TRACING.md#token-usage-and-cost) on the normalized token usage after the provider responds — the same source as the cost span attribute, a different sink. This instrument is Riffer-owned (`riffer.*`, not `gen_ai.*`) so it won't collide if the semantic conventions later define a cost instrument; see [Stability](#stability). Recording is independent of tracing (it fires with `config.tracing.enabled = false`); for a streamed call it fires when the stream drains.

| Value            | Attributes                                                                                         |
| ---------------- | -------------------------------------------------------------------------------------------------- |
| cost of the call | `gen_ai.operation.name` (always `chat`), `gen_ai.provider.name`, `gen_ai.request.model` (when set) |

Pricing is **consumer-configured** — no price table ships with the gem (see [Configuration — Pricing](10_CONFIGURATION.md#pricing)). A call whose model has no configured price records **no** data point, so this metric covers only priced calls; `operation.duration` and `token.usage` still record. A priced call that computes to `0.0` does record a zero data point — only an absent price means there is nothing to measure.

> **Per-call only.** Cost is never recorded at the run (`invoke_agent`) level, for the same reason as token usage: metrics pre-aggregate, so emitting both per-call points and a run total would double-count. Sum the per-call points in your backend for a run total.

## Stability

The instrument shape is a public, versioned contract, in two tiers — mirroring the [tracing contract](16_TRACING.md#stability):

- **`gen_ai.*`** tracks the OpenTelemetry GenAI semantic conventions, pinned to schema version `1.37.0`. That convention is still "Development" status upstream and its names may change; Riffer absorbs such renames deliberately in a release, never silently, with a CHANGELOG entry.
- **`riffer.*`** is Riffer-owned and changes only through a normal version bump and CHANGELOG entry. Riffer-owned metrics live here so they won't collide if semconv later defines an equivalent.

The semantic-convention schema version is a documented pin rather than an instrument attribute — the OpenTelemetry Ruby API can't attach a schema URL to a meter. The runtime version signal is the instrumentation scope: every measurement carries scope name `riffer` at the gem version that recorded it. Pin the Riffer version your dashboards depend on, and watch the CHANGELOG for metrics entries before upgrading.

## Avoid double instrumentation

Riffer records its agent loop's metrics natively. Running a provider-level GenAI instrumentation gem (for example an OpenTelemetry contrib instrumentation for the underlying Anthropic or OpenAI client) _alongside_ Riffer records the same `gen_ai.client.*` metrics twice. Because metrics pre-aggregate, that duplication is **silent** — it inflates counts and distorts distributions in your dashboards without any obvious per-event trace to inspect.

Record one or the other, not both. Since the metrics kill switch is independent of tracing, the usual resolution is to keep Riffer's spans and turn _Riffer's metrics_ off, letting the provider-level instrumentation own the metrics:

```ruby
Riffer.configure do |config|
  config.metrics.enabled = false
end
```

— or disable the provider-level metric instrumentation and let Riffer own them.
