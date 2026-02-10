# frozen_string_literal: true
# rbs_inline: enabled

# Represents the result of a guardrail execution.
#
# Results can be one of three types:
# - pass: Continue with the original data unchanged
# - transform: Continue with transformed data
# - block: Halt execution with a reason
#
# Use the factory methods to create results:
#   Result.pass(data)
#   Result.transform(data)
#   Result.block(reason, metadata: nil)
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
    #
    # +data+ - the original data to pass through.
    #
    #: (untyped) -> Riffer::Guardrails::Result
    def pass(data)
      new(:pass, data)
    end

    # Creates a transform result that continues with transformed data.
    #
    # +data+ - the transformed data.
    #
    #: (untyped) -> Riffer::Guardrails::Result
    def transform(data)
      new(:transform, data)
    end

    # Creates a block result that halts execution.
    #
    # +reason+ - the reason for blocking.
    # +metadata+ - optional additional information.
    #
    #: (String, ?metadata: Hash[Symbol, untyped]?) -> Riffer::Guardrails::Result
    def block(reason, metadata: nil)
      new(:block, reason, metadata: metadata)
    end
  end

  # Creates a new result.
  #
  # +type+ - the result type (:pass, :transform, or :block).
  # +data+ - the data or reason.
  # +metadata+ - optional metadata for block results.
  #
  # Raises Riffer::ArgumentError if the result type is invalid.
  #
  #: (Symbol, untyped, ?metadata: Hash[Symbol, untyped]?) -> void
  def initialize(type, data, metadata: nil)
    raise Riffer::ArgumentError, "Invalid result type: #{type}" unless TYPES.include?(type)

    @type = type
    @data = data
    @metadata = metadata
  end

  # Returns true if this is a pass result.
  #
  #: () -> bool
  def pass?
    type == :pass
  end

  # Returns true if this is a transform result.
  #
  #: () -> bool
  def transform?
    type == :transform
  end

  # Returns true if this is a block result.
  #
  #: () -> bool
  def block?
    type == :block
  end
end
