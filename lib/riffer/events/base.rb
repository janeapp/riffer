# frozen_string_literal: true
# rbs_inline: enabled

# Fields and behavior shared by every completion event. Subclasses add the
# operation-specific fields and define +name+; most also enrich +dimensions+
# and +measurements+ so a generic subscriber can translate them without a
# +case+ on the event type.
class Riffer::Events::Base
  # @rbs @error_type: String?

  # The operation duration in seconds, measured on a monotonic clock.
  attr_reader :duration #: Float

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
  #: (duration: Float, ?error: Exception?, ?error_type: String?, ?tags: Hash[String, String], ?trace_id: String?, ?span_id: String?) -> void
  def initialize(duration:, error: nil, error_type: nil, tags: {}, trace_id: nil, span_id: nil)
    @duration = duration
    @error = error
    @error_type = error_type
    # Copy so one subscriber can't mutate the hash and change what later
    # subscribers (handed the same event) observe.
    @tags = tags.dup.freeze
    @trace_id = trace_id
    @span_id = span_id
  end

  # The dotted event name (e.g. +"riffer.chat"+) — handy for logging. Subclasses
  # define it.
  #--
  #: () -> String
  def name
    raise NotImplementedError
  end

  # The error type when the operation failed — an explicit handled-error type,
  # or a raised exception's class name — else +nil+.
  #--
  #: () -> String?
  def error_type
    @error_type || @error&.class&.name
  end

  # Whether the operation ended in an error, raised or handled.
  #--
  #: () -> bool
  def error?
    !error_type.nil?
  end

  # Numeric facts for this event, keyed by unprefixed metric name — the values a
  # generic subscriber records without knowing the event type. The shared one is
  # +duration+; subclasses add token counts, cost, and the like.
  #--
  #: () -> Hash[String, Numeric]
  def measurements
    {"duration" => duration}
  end

  # Low-cardinality string labels for this event — safe as metric tags.
  # Deliberately excludes unbounded ids (trace_id, span_id, a per-call id);
  # those live on +to_h+ and the typed accessors. Subclasses add provider,
  # model, tool, and so on.
  #--
  #: () -> Hash[String, String]
  def dimensions
    dims = {} #: Hash[String, String]
    type = error_type
    dims["error_type"] = type if type
    dims
  end

  # The per-call tags merged under the framework dimensions — the full label set
  # for a metric. Dimensions win on a key collision, so a caller-supplied tag
  # can't shadow a structural label.
  #--
  #: () -> Hash[String, String]
  def labels
    tags.merge(dimensions)
  end

  # A flat projection of the whole event for structured logging: name, error
  # flag, every measurement and dimension, the correlation ids, and the tags
  # under a +tag.+ prefix — all string-keyed.
  #--
  #: () -> Hash[String, untyped]
  def to_h
    result = {"name" => name, "error" => error?} #: Hash[String, untyped]
    result.merge!(measurements)
    result.merge!(dimensions)
    result["trace_id"] = trace_id if trace_id
    result["span_id"] = span_id if span_id
    tags.each { |key, value| result["tag.#{key}"] = value }
    result
  end
end
