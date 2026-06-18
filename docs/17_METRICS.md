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

## Instruments

Each instrument is documented here as a row carrying its name, instrument type, unit, and attribute set.

### `gen_ai.client.operation.duration`

Histogram, unit `s`. The latency of a single GenAI operation, recorded around the same wrap as the matching [span](16_TRACING.md) on both the success and error paths and timed with a monotonic clock. Recording is independent of tracing — the metric fires even with `config.tracing.enabled = false`. Tell the three operations apart by `gen_ai.operation.name`.

| `gen_ai.operation.name` | Recorded around                                  | Attributes                                                                                                                |
| ----------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `chat`                  | each provider call (`generate_text`/`stream_text`) | `gen_ai.operation.name`, `gen_ai.provider.name`, `gen_ai.request.model` (when set), `error.type` (on error)               |
| `invoke_agent`          | each agent run (`generate`/`stream`)             | `gen_ai.operation.name`, `gen_ai.provider.name`, `gen_ai.request.model`, `gen_ai.agent.name`, `error.type` (on error)     |
| `execute_tool`          | each tool call                                   | `gen_ai.operation.name`, `gen_ai.tool.name`, `error.type` (on error)                                                      |

`error.type` carries the exception class for a raised error; for `execute_tool` it carries the handled error category (e.g. `validation_error`, `timeout_error`) when a tool returns an error result instead of raising — matching the span. `gen_ai.response.model` is not recorded yet; it will land once it is also captured on the chat span.

> **Streamed operations are consumption-paced.** A streamed `chat` or `invoke_agent` records its duration when the stream drains, so the value includes the time your consumer takes to iterate the events, not just provider latency. The matching span behaves the same way.

> **`gen_ai.tool.name` cardinality.** One time series exists per distinct tool name. With a large or dynamic tool set (for example MCP-discovered tools) that can grow unbounded — drop the attribute with a [View](https://opentelemetry.io/docs/specs/otel/metrics/sdk/#view) if your backend strains.

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
