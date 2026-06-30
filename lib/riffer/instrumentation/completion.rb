# frozen_string_literal: true
# rbs_inline: enabled

# The cross-cutting outcome of an instrumented operation, handed to each event
# builder alongside the block's result so it can fill the common event fields.
class Riffer::Instrumentation::Completion # :nodoc: all
  # The operation duration in seconds, from a monotonic clock.
  attr_reader :duration #: Float

  # The raised exception's class name, or +nil+ when the operation didn't raise.
  attr_reader :error_type #: String?

  # The raised exception, or +nil+.
  attr_reader :error #: Exception?

  # The active trace id (hex) when tracing was live, else +nil+.
  attr_reader :trace_id #: String?

  # The active span id (hex) when tracing was live, else +nil+.
  attr_reader :span_id #: String?

  #--
  #: (duration: Float, ?error_type: String?, ?error: Exception?, ?trace_id: String?, ?span_id: String?) -> void
  def initialize(duration:, error_type: nil, error: nil, trace_id: nil, span_id: nil)
    @duration = duration
    @error_type = error_type
    @error = error
    @trace_id = trace_id
    @span_id = span_id
  end
end
