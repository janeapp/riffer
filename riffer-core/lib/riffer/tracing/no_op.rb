# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Tracing::NoOp # :nodoc: all
  extend self

  class Span
    #--
    #: (String, untyped) -> void
    def set_attribute(key, value); end

    #--
    #: (String, ?attributes: Hash[String, untyped]?) -> void
    def add_event(name, attributes: nil); end

    #--
    #: (Exception) -> void
    def record_exception(exception); end

    #--
    #: (?String) -> void
    def error!(description = ""); end

    #--
    #: () -> bool
    def recording?
      false
    end
  end

  SPAN = Span.new.freeze #: Riffer::Tracing::NoOp::Span

  #--
  #: [R] (String, **untyped) { (Riffer::Tracing::NoOp::Span) -> R } -> R
  def in_span(_name, **)
    yield SPAN
  end

  #--
  #: () -> nil
  def current_context
    nil
  end

  #--
  #: [R] (untyped) { () -> R } -> R
  def with_context(_context)
    yield
  end
end
