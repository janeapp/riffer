# frozen_string_literal: true
# rbs_inline: enabled

# The instrumentation bracket every observable operation runs through. It times
# the work, opens a live tracing span around it (a no-op until a backend is
# wired), and publishes one completion event built by +event+. Tracing stays
# in-band because a span must be current while the work runs so nested spans
# attach; the event is fire-and-forget, so metrics and other backends subscribe.
module Riffer::Instrumentation # :nodoc: all
  extend self

  # Wraps the block: opens the span, captures the result and a Completion, and
  # publishes the event +event+ builds from <tt>(result, completion)</tt>.
  # +event+ runs in an ensure, so a raising operation still emits — with a +nil+
  # result and the error on the Completion.
  #--
  #: [R] (String, attributes: Hash[String, untyped], kind: Symbol, event: ^(untyped, Riffer::Instrumentation::Completion) -> Riffer::Events::Base?) { ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span)) -> R } -> R
  def instrument(span_name, attributes:, kind:, event:)
    start = monotonic_now
    error = nil #: Exception?
    trace_id = nil #: String?
    span_id = nil #: String?
    result = nil #: untyped

    begin
      Riffer::Tracing.in_span(span_name, attributes: attributes, kind: kind) do |span|
        if Riffer::Events.subscribed?
          ids = Riffer::Tracing.current_trace_ids
          trace_id = ids[:trace_id]
          span_id = ids[:span_id]
        end
        result = yield span
      rescue => raised
        # Re-raise so the tracing backend records the exception and error status;
        # error.type is the one semconv attribute it doesn't set.
        error = raised
        span.set_attribute("error.type", raised.class.name)
        raise
      end
    ensure
      publish(event, result, start, error, trace_id, span_id)
    end
  end

  private

  #--
  #: [R] (^(R?, Riffer::Instrumentation::Completion) -> Riffer::Events::Base?, R?, Float, Exception?, String?, String?) -> void
  def publish(event, result, start, error, trace_id, span_id)
    return unless Riffer::Events.subscribed?

    completion = Completion.new(
      duration: monotonic_now - start,
      error_type: error&.class&.name,
      error: error,
      trace_id: trace_id,
      span_id: span_id
    )

    built = event.call(result, completion)

    Riffer::Events.publish(built) if built
  end

  # The monotonic clock in seconds — immune to wall-clock adjustments, so a
  # duration never goes negative across an NTP step.
  #--
  #: () -> Float
  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
