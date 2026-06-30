# Events

Riffer publishes a rich **completion event** for every operation it runs — each LLM call, agent run, tool call, and guardrail — through a tiny synchronous in-process bus. Metrics, logs, and any other observability are **consumers** of that bus: you write a subscriber that maps events to your backend (Datadog, StatsD, Prometheus, OpenTelemetry, structured logs). Riffer ships no metrics backend of its own — the events are the contract, and you decide what to do with them. This page is the reference for that contract.

Events carry **raw domain facts** (a `TokenUsage` object, a cost float, an exception), never a vendor's vocabulary, so no backend is privileged. [Tracing](16_TRACING.md) stays separate and in-band — a span must be live _during_ an operation so nested spans attach — but every completion event also carries the active `trace_id`/`span_id` when tracing is on, so a metric or log line can be correlated back to its trace.

## Subscribing

A subscriber is any object responding to `#call(event)`, or a block. Register it on `config.events`; an idle bus with no subscribers costs nothing.

```ruby
Riffer.configure do |config|
  config.events.subscribe do |event|
    case event
    when Riffer::Events::ChatCompleted
      StatsD.distribution("llm.tokens", event.token_usage&.total_tokens || 0, tags: ["model:#{event.model}"])
    when Riffer::Events::ToolExecuted
      StatsD.increment("llm.tool.#{event.outcome}", tags: ["tool:#{event.tool}"])
    end
  end
end
```

Every subscriber receives **every** event and filters by type — typically with a `case` on the event class. `subscribe` returns the registered subscriber, which you can later pass to `config.events.unsubscribe`; `config.events.clear` removes all of them. The configuration knobs live in [Configuration — Events](10_CONFIGURATION.md#events).

### Delivery and error isolation

Delivery is **synchronous and in-process**: subscribers run inline, in registration order, on the thread (or fiber, when streaming) that produced the event. Keep them fast — a slow subscriber slows the operation. If a subscriber needs to do real work, enqueue it and return.

A subscriber that raises is **isolated**: the exception is routed to `config.events.on_error` (which by default logs a warning) and delivery continues to the next subscriber, so an observability failure never breaks the LLM call that produced the event. Set `config.events.on_error` to your own handler — re-raise from it for strict, fail-fast behavior in development or tests.

## Events

Every event is a class under `Riffer::Events`, sharing the common fields below from `Riffer::Events::Base` and adding operation-specific ones. Events fire on both the success and failure paths; a streamed operation fires when its stream drains, so its `duration` includes consumer iteration time (matching the [span](16_TRACING.md)).

### Common fields (`Riffer::Events::Base`)

| Field        | Type                  | Notes                                                                                              |
| ------------ | --------------------- | -------------------------------------------------------------------------------------------------- |
| `name`       | `String`              | The dotted event name (`"riffer.chat"`, `"riffer.invoke_agent"`, …) — handy for logging.           |
| `operation`  | `Symbol`              | `:chat`, `:invoke_agent`, `:execute_tool`, or `:execute_guardrail`.                                |
| `duration`   | `Float`               | Seconds, from a monotonic clock.                                                                   |
| `error_type` | `String?`             | A raised exception's class name, or a handled error's type; `nil` on success.                      |
| `error`      | `Exception?`          | The raised exception, when one was raised. A handled error carries `error_type` but no exception.  |
| `error?`     | `bool`                | `true` when `error_type` is set.                                                                   |
| `tags`       | `Hash[String,String]` | The per-call [tags](03_AGENTS.md#per-call-tags), unprefixed — a subscriber namespaces them itself. |
| `trace_id`   | `String?`             | The active trace id (hex) when tracing was live, else `nil`.                                       |
| `span_id`    | `String?`             | The active span id (hex) when tracing was live, else `nil`.                                        |

### `Riffer::Events::ChatCompleted`

One LLM chat call. Adds `provider` (`String`), `model` (`String?`), `token_usage` ([`Riffer::Providers::TokenUsage?`](08_MESSAGES.md) — input/output/cache buckets), `cost` (`Float?`, derived from the usage when the model is priced), and `finish_reason` ([`Riffer::Providers::FinishReason?`](16_TRACING.md)).

### `Riffer::Events::AgentInvoked`

One agent run. Adds `agent` (`String`), `provider` (`String`), `model` (`String?`), `token_usage` (`Riffer::Providers::TokenUsage?`), `cost` (`Float?`), and `steps` (`Integer`).

> **Aggregate vs per-call.** `token_usage`/`cost` here are the run **total** across every chat call. To avoid double-counting, pick one level: sum `ChatCompleted` for per-call figures _or_ read `AgentInvoked` for the run total — never both.

### `Riffer::Events::ToolExecuted`

One tool call. Adds `tool` (`String`), `call_id` (`String`), and `outcome` (`Symbol` — `:success` or `:error`). A returned error response and a raised exception both yield `:error`; the raised case also populates `error`.

### `Riffer::Events::GuardrailExecuted`

One guardrail execution. Adds `guardrail` (`String`), `phase` (`Symbol` — `:before` or `:after`), and `outcome` (`Symbol?` — `:pass`, `:transform`, or `:block`; `nil` when the guardrail raised).

## Example: a Datadog subscriber

Because events carry raw facts, the mapping to your backend's vocabulary lives in your subscriber. The same shape drives StatsD, Prometheus, OpenTelemetry, or a log line — pick the fields you care about.

```ruby
class DatadogMetrics
  def initialize(statsd) = @statsd = statsd

  def call(event)
    base = event.tags.map { |k, v| "#{k}:#{v}" }
    case event
    when Riffer::Events::ChatCompleted
      @statsd.distribution("llm.chat.duration", event.duration, tags: base + ["model:#{event.model}"])
      @statsd.distribution("llm.chat.cost", event.cost, tags: base) if event.cost
    when Riffer::Events::ToolExecuted
      @statsd.increment("llm.tool.calls", tags: base + ["tool:#{event.tool}", "outcome:#{event.outcome}"])
    when Riffer::Events::GuardrailExecuted
      @statsd.increment("llm.guardrail", tags: base + ["guardrail:#{event.guardrail}", "outcome:#{event.outcome}"])
    end
  end
end

Riffer.configure do |config|
  config.events.subscribe(DatadogMetrics.new(Datadog::Statsd.new))
end
```

## Stability

The event classes and their documented fields are a **public, versioned contract**. Adding a new field or a new event type is non-breaking — the subscribe-all-and-pattern-match design means a subscriber simply ignores what it doesn't recognize — so build against the fields you read. Removing, renaming, or retyping an existing field is a breaking change, called out in the CHANGELOG.
