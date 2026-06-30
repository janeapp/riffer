# frozen_string_literal: true
# rbs_inline: enabled

# Fields and behavior shared by every completion event. Subclasses add the
# operation-specific fields and define +operation+ and +name+.
class Riffer::Events::Base
  # The operation duration in seconds, measured on a monotonic clock.
  attr_reader :duration #: Float

  # The error type when the operation failed — a raised exception's class name
  # or a handled error's type — else +nil+.
  attr_reader :error_type #: String?

  # The raised exception when the operation raised, else +nil+. A handled error
  # outcome (e.g. a tool returning an error response) carries an +error_type+
  # but no exception.
  attr_reader :error #: Exception?

  # The per-call tags, unprefixed; a subscriber namespaces them for its backend.
  attr_reader :tags #: Hash[String, String]

  # The active trace id (hex) when tracing was live, else +nil+.
  attr_reader :trace_id #: String?

  # The active span id (hex) when tracing was live, else +nil+.
  attr_reader :span_id #: String?

  #--
  #: (duration: Float, ?error_type: String?, ?error: Exception?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(duration:, error_type: nil, error: nil, tags: {}, trace_id: nil, span_id: nil)
    @duration = duration
    @error_type = error_type
    @error = error
    # Copy so one subscriber can't mutate the hash and change what later
    # subscribers (handed the same event) observe.
    @tags = tags.dup.freeze
    @trace_id = trace_id
    @span_id = span_id
  end

  # Whether the operation ended in an error, raised or handled.
  #--
  #: () -> bool
  def error?
    !error_type.nil?
  end
end
