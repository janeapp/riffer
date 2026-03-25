# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Guardrails::Result
  TYPES = %i[pass transform block].freeze #: Array[Symbol]

  attr_reader :type #: Symbol

  attr_reader :data #: untyped

  attr_reader :metadata #: Hash[Symbol, untyped]?

  class << self
    #: (untyped) -> Riffer::Guardrails::Result
    def pass(data)
      new(:pass, data)
    end

    #: (untyped) -> Riffer::Guardrails::Result
    def transform(data)
      new(:transform, data)
    end

    #: (String, ?metadata: Hash[Symbol, untyped]?) -> Riffer::Guardrails::Result
    def block(reason, metadata: nil)
      new(:block, reason, metadata: metadata)
    end
  end

  #: (Symbol, untyped, ?metadata: Hash[Symbol, untyped]?) -> void
  def initialize(type, data, metadata: nil)
    raise Riffer::ArgumentError, "Invalid result type: #{type}" unless TYPES.include?(type)

    @type = type
    @data = data
    @metadata = metadata
  end

  #: () -> bool
  def pass?
    type == :pass
  end

  #: () -> bool
  def transform?
    type == :transform
  end

  #: () -> bool
  def block?
    type == :block
  end
end
