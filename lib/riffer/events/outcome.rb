# frozen_string_literal: true
# rbs_inline: enabled

# The cross-cutting result of an instrumented operation, handed to each event
# builder so it fills the shared event fields with one +**outcome.to_h+ splat
# rather than copying them one by one.
class Riffer::Events::Outcome # :nodoc: all
  # The operation duration in seconds, from a monotonic clock.
  attr_reader :duration #: Float

  # The raised exception, or +nil+.
  attr_reader :error #: Exception?

  # The active trace id (hex) when tracing was live, else +nil+.
  attr_reader :trace_id #: String?

  # The active span id (hex) when tracing was live, else +nil+.
  attr_reader :span_id #: String?

  #--
  #: (duration: Float, ?error: Exception?, ?trace_id: String?, ?span_id: String?) -> void
  def initialize(duration:, error: nil, trace_id: nil, span_id: nil)
    @duration = duration
    @error = error
    @trace_id = trace_id
    @span_id = span_id
  end

  # The raised exception's class name, or +nil+ — the base of an event's
  # +error_type+, which a handled-error builder may override.
  #--
  #: () -> String?
  def error_type
    error&.class&.name
  end

  # The shared event fields as constructor keywords, for +**outcome.to_h+. A
  # record type (not a plain Hash) so the splat satisfies each event's required
  # +duration:+ under Steep.
  #--
  #: () -> { duration: Float, error: Exception?, trace_id: String?, span_id: String? }
  def to_h
    {duration: duration, error: error, trace_id: trace_id, span_id: span_id}
  end
end
