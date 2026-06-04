# frozen_string_literal: true
# rbs_inline: enabled

# Represents the result of a guardrail execution: +pass+ (continue unchanged),
# +transform+ (continue with changed data), or +block+ (halt with a reason).
class Riffer::Guardrails::Result
  TYPES = %i[pass transform block].freeze #: Array[Symbol]

  # The result type (:pass, :transform, or :block).
  attr_reader :type #: Symbol

  # The data (for pass/transform) or reason (for block).
  attr_reader :data #: untyped

  # Optional metadata for block results.
  attr_reader :metadata #: Hash[Symbol, untyped]?

  class << self
    # Creates a pass result that continues with unchanged data.
    #--
    #: (untyped) -> Riffer::Guardrails::Result
    def pass(data)
      new(:pass, data)
    end

    # Creates a transform result that continues with transformed data.
    #--
    #: (untyped) -> Riffer::Guardrails::Result
    def transform(data)
      new(:transform, data)
    end

    # Creates a block result that halts execution.
    #--
    #: (String, ?metadata: Hash[Symbol, untyped]?) -> Riffer::Guardrails::Result
    def block(reason, metadata: nil)
      new(:block, reason, metadata: metadata)
    end
  end

  # Raises Riffer::ArgumentError if +type+ is not :pass, :transform, or :block.
  #--
  #: (Symbol, untyped, ?metadata: Hash[Symbol, untyped]?) -> void
  def initialize(type, data, metadata: nil)
    raise Riffer::ArgumentError, "Invalid result type: #{type}" unless TYPES.include?(type)

    @type = type
    @data = data
    @metadata = metadata
  end

  # Returns true if this is a pass result.
  #
  #--
  #: () -> bool
  def pass?
    type == :pass
  end

  # Returns true if this is a transform result.
  #
  #--
  #: () -> bool
  def transform?
    type == :transform
  end

  # Returns true if this is a block result.
  #
  #--
  #: () -> bool
  def block?
    type == :block
  end
end
