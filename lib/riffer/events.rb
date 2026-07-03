# frozen_string_literal: true
# rbs_inline: enabled

# Synchronous in-process event bus. Riffer publishes one completion event per
# instrumented operation, and subscribers registered through +config.events+
# receive the events that match their filter. Observability backends (metrics,
# Datadog, logs) are subscribers, so observability never couples to one vendor.
module Riffer::Events
  extend self

  # The instrumentation bracket every observable operation runs through — the
  # outer, out-of-band layer that wraps the inner, in-band tracing span. It
  # opens the span (so provider and host child spans nest and the trace context
  # stays live during the work), times the block on a monotonic clock, and on
  # the way out builds and publishes the completion event that +event+ returns
  # from <tt>(result, outcome)</tt>. +event+ runs in an ensure, so a raising
  # operation still emits — with a +nil+ result and the error on the Outcome.
  #--
  #: [R] (String, attributes: Hash[String, untyped], kind: Symbol, event: ^(untyped, Riffer::Events::Outcome) -> Riffer::Events::Base?) { ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span)) -> R } -> R
  def observe(span_name, attributes:, kind:, event:)
    start = monotonic_now
    error = nil #: Exception?
    trace_id = nil #: String?
    span_id = nil #: String?
    result = nil #: untyped

    begin
      Riffer::Tracing.in_span(span_name, attributes: attributes, kind: kind) do |span|
        ids = Riffer::Tracing.current_trace_ids
        trace_id = ids[:trace_id]
        span_id = ids[:span_id]
        result = yield span
      rescue => raised
        # Re-raise so the tracing backend records the exception and error status;
        # error.type is the one semconv attribute it doesn't set.
        error = raised
        span.set_attribute("error.type", raised.class.name)
        raise
      end
    ensure
      publish_completion(event, result, start, error, trace_id, span_id)
    end
  end

  # Whether any subscriber is registered. Call sites build an event only when
  # someone is listening, so an idle bus costs nothing.
  #--
  #: () -> bool
  def subscribed?
    Riffer.config.events.subscribers.any?
  end

  # Publishes an event to every matching subscriber synchronously, in
  # registration order. A subscriber that raises is isolated — the error routes
  # to +config.events.on_error+ and delivery continues — so an observability
  # failure never breaks the operation that produced the event.
  #--
  #: (Riffer::Events::Base) -> void
  def publish(event)
    events_config = Riffer.config.events
    events_config.each_subscriber(event) do |subscriber|
      subscriber.call(event)
    rescue => error
      handle_error(events_config.on_error, error, event)
    end
  end

  private

  # Builds the Outcome and, from it, the event, then publishes. Runs in
  # +observe+'s ensure, so a failure building or publishing the event must not
  # break — or mask the error of — the operation it observes.
  #--
  #: (^(untyped, Riffer::Events::Outcome) -> Riffer::Events::Base?, untyped, Float, Exception?, String?, String?) -> void
  def publish_completion(event, result, start, error, trace_id, span_id)
    return unless subscribed?

    outcome = Outcome.new(
      duration: monotonic_now - start,
      error: error,
      trace_id: trace_id,
      span_id: span_id
    )

    built = event.call(result, outcome)

    publish(built) if built
  rescue
    nil
  end

  # The error handler is the last line of defense; if it raises too there's
  # nowhere left to route, so swallow to keep delivery going to the next
  # subscriber.
  #--
  #: (^(Exception, Riffer::Events::Base) -> void, Exception, Riffer::Events::Base) -> void
  def handle_error(handler, error, event)
    handler.call(error, event)
  rescue
    nil
  end

  # The monotonic clock in seconds — immune to wall-clock adjustments, so a
  # duration never goes negative across an NTP step.
  #--
  #: () -> Float
  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
