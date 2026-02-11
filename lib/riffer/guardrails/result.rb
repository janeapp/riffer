# frozen_string_literal: true

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
  TYPES = %i[pass transform block].freeze

  # The result type (:pass, :transform, or :block).
  #
  # Returns Symbol.
  attr_reader :type

  # The data (for pass/transform) or reason (for block).
  #
  # Returns Object.
  attr_reader :data

  # Optional metadata for block results.
  #
  # Returns Hash or nil.
  attr_reader :metadata

  class << self
    # Creates a pass result that continues with unchanged data.
    #
    # data:: Object - the original data to pass through
    #
    # Returns Result.
    def pass(data)
      new(:pass, data)
    end

    # Creates a transform result that continues with transformed data.
    #
    # data:: Object - the transformed data
    #
    # Returns Result.
    def transform(data)
      new(:transform, data)
    end

    # Creates a block result that halts execution.
    #
    # reason:: String - the reason for blocking
    # metadata:: Hash or nil - optional additional information
    #
    # Returns Result.
    def block(reason, metadata: nil)
      new(:block, reason, metadata: metadata)
    end
  end

  # Creates a new result.
  #
  # type:: Symbol - the result type (:pass, :transform, or :block)
  # data:: Object - the data or reason
  # metadata:: Hash or nil - optional metadata for block results
  def initialize(type, data, metadata: nil)
    raise Riffer::ArgumentError, "Invalid result type: #{type}" unless TYPES.include?(type)

    @type = type
    @data = data
    @metadata = metadata
  end

  # Returns true if this is a pass result.
  #
  # Returns Boolean.
  def pass?
    type == :pass
  end

  # Returns true if this is a transform result.
  #
  # Returns Boolean.
  def transform?
    type == :transform
  end

  # Returns true if this is a block result.
  #
  # Returns Boolean.
  def block?
    type == :block
  end
end
