# Tracing

Riffer instruments its agent loop with [OpenTelemetry](https://opentelemetry.io/) spans, following the [GenAI semantic conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/). The emitted span shape — names, attributes, and hierarchy — is a public, versioned contract you can build dashboards, alerts, and cost reporting against. This page is the reference for that contract.

Riffer only _emits_ spans. The host application owns the OpenTelemetry SDK, the exporter, sampling, and service naming — the standard OTEL split. Without a host SDK, every span is a silent no-op and Riffer carries no OpenTelemetry gem dependency.

## Enabling tracing

Add the OpenTelemetry SDK to your host application and configure an exporter. Riffer detects the API at runtime and starts emitting through whatever provider the SDK configures — there is nothing to switch on in Riffer beyond the SDK being present.

```ruby
# Gemfile
gem "opentelemetry-sdk"
```

```ruby
require "opentelemetry/sdk"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "my-agent-host"
end
```

To see Riffer's spans on stdout while developing locally, wire in the console exporter:

```ruby
require "opentelemetry/sdk"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "my-agent-host"
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(
      OpenTelemetry::SDK::Trace::Export::ConsoleSpanExporter.new
    )
  )
end
```

Any backend that implements the OpenTelemetry Traces API ingests Riffer's spans with no second pipeline — including the `datadog` gem (`require "datadog/opentelemetry"`), which routes them through an existing tracer so they nest inside the host's live trace. For real exporter and collector setup (OTLP, sampling, resource attributes), see the [OpenTelemetry Ruby docs](https://opentelemetry.io/docs/languages/ruby/).

The three tracing knobs — the `enabled` kill switch, opt-in message-content capture, and an explicit tracer provider for tests — live in [Configuration — Tracing](10_CONFIGURATION.md#tracing).

Spans are emitted under the instrumentation scope named `riffer`, versioned with the Riffer gem version. That scope version is the runtime signal for which release produced a span; see [Stability](#stability).

## Spans

Riffer emits three span types. A single agent run produces one `invoke_agent` span wrapping one `chat` span per model call and one `execute_tool` span per tool call, interleaved in execution order:

```
invoke_agent {agent}             INTERNAL
├─ chat {model}                  CLIENT     (one per LLM call)
├─ execute_tool {tool}           INTERNAL   (one per tool call)
│   └─ (host spans nest here via around_tool_call / tool internals)
├─ chat {model}
└─ …
```

The `execute_tool` span opens _outside_ Riffer's `around_tool_call` hook, so any spans a host emits from that hook — or from inside the tool itself — nest beneath it. See [Advanced Tools](07_TOOL_ADVANCED.md) for the hook.

### Reading the attribute tables

Every attribute a span can carry is listed below, including the conditional ones — you can't query a key you don't know exists. The **Present** column tells you when to expect each:

- **`Always`** — emitted on every span of that type.
- **`On <something happened>`** (e.g. `On a tripwire`, `On failure`) — _path-conditional_: presence is itself a signal. If `riffer.tripwire.phase` is set, a guardrail tripped. Filter on these with confidence.
- **`When the provider reports it`** / **`When the caller set it`** — _best-effort_: may be absent even on a perfectly healthy span, because it depends on what the upstream provider returned or what options the caller passed. Guard or coalesce these in queries.

The contract promise is: **when present**, a key carries the documented meaning and type. It is _not_ a promise that every key appears on every span.

## `invoke_agent {agent}` — the run span

`INTERNAL`. One per call to `Agent#generate` or `Agent#stream`. The span name suffix is the agent's identifier (e.g. `invoke_agent weather-agent`).

| Attribute                                  | Type   | Present                                              |
| ------------------------------------------ | ------ | ---------------------------------------------------- |
| `gen_ai.operation.name`                    | string | Always (`"invoke_agent"`)                            |
| `gen_ai.agent.name`                        | string | Always — the agent's identifier                      |
| `gen_ai.provider.name`                     | string | Always — see [provider names](#provider-names)       |
| `gen_ai.request.model`                     | string | Always — the agent's configured model                |
| `riffer.steps`                             | int    | Always — number of LLM calls in the run              |
| `gen_ai.usage.input_tokens`                | int    | When the run made an LLM call that reported usage    |
| `gen_ai.usage.output_tokens`               | int    | When the run made an LLM call that reported usage    |
| `gen_ai.usage.cache_read.input_tokens`     | int    | When the provider reported cache reads               |
| `gen_ai.usage.cache_creation.input_tokens` | int    | When the provider reported cache writes              |
| `riffer.interrupt.reason`                  | string | On interrupt (e.g. approval needed, max steps)       |
| `riffer.tripwire.guardrail`                | string | On a guardrail tripwire, when the guardrail is named |
| `riffer.tripwire.reason`                   | string | On a guardrail tripwire                              |
| `riffer.tripwire.phase`                    | string | On a guardrail tripwire (`"before"` / `"after"`)     |
| `error.type`                               | string | On an unhandled exception                            |

Usage on this span is the run total, aggregated across every step. See [Token usage](#token-usage) for the trap this creates.

## `chat {model}` — the LLM call span

`CLIENT`. One per model call, in both `generate` and `stream`. The span name suffix is the model (e.g. `chat gpt-4`), or just `chat` when no model is set.

| Attribute                                  | Type     | Present                                                                       |
| ------------------------------------------ | -------- | ----------------------------------------------------------------------------- |
| `gen_ai.operation.name`                    | string   | Always (`"chat"`)                                                             |
| `gen_ai.provider.name`                     | string   | Always — see [provider names](#provider-names)                                |
| `gen_ai.request.model`                     | string   | When a model is set                                                           |
| `gen_ai.request.temperature`               | float    | When the caller set it                                                        |
| `gen_ai.request.max_tokens`                | int      | When the caller set `max_tokens` or `max_output_tokens`                       |
| `gen_ai.request.top_p`                     | float    | When the caller set it                                                        |
| `gen_ai.request.top_k`                     | int      | When the caller set it                                                        |
| `gen_ai.request.frequency_penalty`         | float    | When the caller set it                                                        |
| `gen_ai.request.presence_penalty`          | float    | When the caller set it                                                        |
| `gen_ai.request.seed`                      | int      | When the caller set it                                                        |
| `gen_ai.request.stop_sequences`            | string[] | When the caller set it                                                        |
| `gen_ai.usage.input_tokens`                | int      | When the provider reported usage                                              |
| `gen_ai.usage.output_tokens`               | int      | When the provider reported usage                                              |
| `gen_ai.usage.cache_read.input_tokens`     | int      | When the provider reported cache reads                                        |
| `gen_ai.usage.cache_creation.input_tokens` | int      | When the provider reported cache writes                                       |
| `gen_ai.response.finish_reasons`           | string[] | When the provider reported a finish reason                                    |
| `riffer.finish_reason.raw`                 | string   | When the raw value differs from the normalized one                            |
| `gen_ai.input.messages`                    | string   | When `capture_messages` is on (JSON; see [capture](#message-content-capture)) |
| `gen_ai.system_instructions`               | string   | When `capture_messages` is on and a system prompt exists                      |
| `gen_ai.output.messages`                   | string   | When `capture_messages` is on (JSON)                                          |
| `error.type`                               | string   | On an unhandled exception                                                     |

`gen_ai.response.finish_reasons` is an array of exactly one normalized value, from the fixed vocabulary `stop`, `length`, `tool_calls`, `content_filter`, `error`, `other`. When the provider's raw wire value carries more nuance than the normalized one, the raw string is preserved on `riffer.finish_reason.raw`.

## `execute_tool {tool}` — the tool call span

`INTERNAL`. One per tool call dispatched by the runtime. The span name suffix is the tool's name (e.g. `execute_tool get_weather`).

| Attribute                    | Type   | Present                                                                 |
| ---------------------------- | ------ | ----------------------------------------------------------------------- |
| `gen_ai.operation.name`      | string | Always (`"execute_tool"`)                                               |
| `gen_ai.tool.name`           | string | Always                                                                  |
| `gen_ai.tool.call.id`        | string | Always — the originating tool-call id                                   |
| `error.type`                 | string | On a tool error (see below)                                             |
| `gen_ai.tool.call.arguments` | string | When `capture_messages` is on (see [capture](#message-content-capture)) |
| `gen_ai.tool.call.result`    | string | When `capture_messages` is on                                           |

A tool failure comes in two shapes, distinguished by span status:

- **Handled error** — the tool returned an error response. `error.type` carries the category and the **span status stays unset** (the run continues). The framework's categories are `unknown_tool`, `validation_error`, `timeout_error`, and `execution_error`; a custom tool may set its own via `Riffer::Tools::Response.error(type:)`.
- **Unhandled exception** — the dispatch raised. `error.type` is the exception class name and the **span status is `ERROR`**, with the exception recorded.

This status convention is the same on `chat` and `invoke_agent`: an unhandled exception sets `error.type` to the class name and marks the span `ERROR`; everything else leaves the status unset.

## Example trace

A `generate` run where the model calls one tool, then answers — using the OpenAI provider with `gpt-4`:

```
invoke_agent weather-agent          INTERNAL
  gen_ai.agent.name      = weather-agent
  gen_ai.provider.name   = openai
  gen_ai.request.model   = gpt-4
  riffer.steps           = 2
  gen_ai.usage.input_tokens  = 1240
  gen_ai.usage.output_tokens = 86
├─ chat gpt-4                       CLIENT
│    gen_ai.request.model            = gpt-4
│    gen_ai.response.finish_reasons  = ["tool_calls"]
│    gen_ai.usage.input_tokens       = 612
│    gen_ai.usage.output_tokens      = 48
├─ execute_tool get_weather         INTERNAL
│    gen_ai.tool.name     = get_weather
│    gen_ai.tool.call.id  = tc_42
└─ chat gpt-4                       CLIENT
     gen_ai.request.model            = gpt-4
     gen_ai.response.finish_reasons  = ["stop"]
     gen_ai.usage.input_tokens       = 628
     gen_ai.usage.output_tokens      = 38
```

## Token usage

`gen_ai.usage.input_tokens` is the **total** prompt tokens for the call, **cache-inclusive**, per the GenAI semantic conventions. `gen_ai.usage.cache_read.input_tokens` and `gen_ai.usage.cache_creation.input_tokens` are **subsets of that total** — the portion served from, or written to, the provider's prompt cache. They are _not_ additional tokens; do not add them on top of `input_tokens`.

```
input_tokens                 = 1000
cache_read.input_tokens      =  800   → 800 of the 1000 were cache hits
                                        (≈ 200 billed as new input)
```

Riffer normalizes this across providers, so the number may differ from a provider's native API field. Anthropic's raw `input_tokens` _excludes_ the cache buckets — Riffer folds them in. OpenAI's already includes them. Either way the span value means the same thing.

**Don't double-count across spans.** Usage on a `chat` span is per-call; usage on the enclosing `invoke_agent` span is the run total already summed across every `chat`. Aggregate one level or the other, never both.

## Message content capture

The prompt and completion content attributes — `gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions` on `chat`, and `gen_ai.tool.call.arguments` / `gen_ai.tool.call.result` on `execute_tool` — are **off by default** and gated behind `config.tracing.capture_messages`. Message content routinely carries sensitive data (including PHI); leave capture off unless your trace backend is an appropriate destination for it.

When enabled, content is serialized as GenAI-semconv JSON strings. File attachments serialize as metadata-only stubs (media type and name, never bytes). Riffer applies no size limit of its own — cap oversized attributes with the OTEL SDK's attribute length limits. See [Configuration — Tracing](10_CONFIGURATION.md#tracing) for the knob.

## Provider names

`gen_ai.provider.name` carries a GenAI-semconv well-known value where one exists: `openai`, `anthropic`, `aws.bedrock`, `azure.ai.openai`, `gcp.gemini`, `openrouter`. A custom provider that doesn't override the value defaults to the snake_cased form of its class name, so enabling tracing never breaks an otherwise-working provider.

## Stability

The span and attribute shape is a public, versioned contract, in two tiers:

- **`gen_ai.*`** tracks the OpenTelemetry GenAI semantic conventions, pinned to schema version `1.37.0`. That convention is still "Development" status upstream and its attribute names may change; Riffer absorbs such renames deliberately in a release, never silently, with a CHANGELOG entry.
- **`riffer.*`** is Riffer-owned (`riffer.steps`, `riffer.interrupt.reason`, `riffer.tripwire.*`, `riffer.finish_reason.raw`) and changes only through a normal version bump and CHANGELOG entry.

The semantic-convention schema version is a documented pin rather than a span attribute — the OpenTelemetry Ruby API can't attach a schema URL to a tracer. The runtime version signal is the instrumentation scope: every span carries scope name `riffer` at the gem version that emitted it. Pin the Riffer version your dashboards depend on, and watch the CHANGELOG for tracing entries before upgrading.

## Avoid double instrumentation

Riffer instruments the agent loop natively. Running a provider-level GenAI instrumentation gem (for example an OpenTelemetry contrib instrumentation for the underlying Anthropic or OpenAI client) _alongside_ Riffer duplicates the `chat` spans and double-counts token usage. Run one or the other, not both — disable the provider-level instrumentation when Riffer's loop spans are active.
