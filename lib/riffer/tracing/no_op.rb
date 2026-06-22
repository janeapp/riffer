# frozen_string_literal: true
# rbs_inline: enabled

# No-op tracing backend, used when OTEL is unavailable or tracing is
# disabled.
module Riffer::Tracing::NoOp # :nodoc: all
  extend self

  # No-op stand-in for a span; answers <tt>recording?</tt> with +false+ so
  # callers can skip expensive attribute serialization.
  class Span
    #--
    #: (String, untyped) -> void
    def set_attribute(key, value)
    end

    #--
    #: (String, ?attributes: Hash[String, untyped]?) -> void
    def add_event(name, attributes: nil)
    end

    #--
    #: (Exception) -> void
    def record_exception(exception)
    end

    #--
    #: (?String) -> void
    def error!(description = "")
    end

    #--
    #: () -> bool
    def recording?
      false
    end
  end

  SPAN = Span.new.freeze #: Riffer::Tracing::NoOp::Span

  # Yields the no-op span, ignoring all span options.
  #--
  #: [R] (String, **untyped) { (Riffer::Tracing::NoOp::Span) -> R } -> R
  def in_span(_name, **)
    yield SPAN
  end

  # Returns +nil+; there is no trace context without OTEL.
  #--
  #: () -> nil
  def current_context
    nil
  end

  # Yields immediately; there is no context to attach.
  #--
  #: [R] (untyped) { () -> R } -> R
  def with_context(_context)
    yield
  end
end
