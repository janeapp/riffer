# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Agent::Context
  # @rbs @data: Hash[Symbol, untyped]

  RESERVED_KEYS = %i[skills token_usage mcp_progressive_tools discovered_tools].freeze #: Array[Symbol]

  # Raises Riffer::ArgumentError if +data+ contains a reserved key.
  #--
  #: (?Hash[Symbol, untyped]) -> void
  def initialize(data = {})
    reserved = data.keys & RESERVED_KEYS
    if reserved.any?
      raise Riffer::ArgumentError,
            "Reserved keys cannot be passed in context: #{reserved.join(', ')}"
    end

    @data = data.dup
    @data[:skills] = nil
    @data[:token_usage] = nil
    @data[:mcp_progressive_tools] = nil
    @data[:discovered_tools] = nil
  end

  #--
  #: () -> Riffer::Skills::Context?
  def skills
    @data[:skills]
  end

  #--
  #: (Riffer::Skills::Context?) -> Riffer::Skills::Context?
  def skills=(value)
    unless value.nil? || value.is_a?(Riffer::Skills::Context)
      raise Riffer::ArgumentError,
            "skills must be a Riffer::Skills::Context or nil, got #{value.class}"
    end
    @data[:skills] = value
  end

  # Cumulative across every run on this agent.
  #--
  #: () -> Riffer::Providers::TokenUsage?
  def token_usage
    @data[:token_usage]
  end

  #--
  #: (Riffer::Providers::TokenUsage?) -> Riffer::Providers::TokenUsage?
  def token_usage=(value)
    unless value.nil? || value.is_a?(Riffer::Providers::TokenUsage)
      raise Riffer::ArgumentError,
            "token_usage must be a Riffer::Providers::TokenUsage or nil, got #{value.class}"
    end
    @data[:token_usage] = value
  end

  #--
  #: (Symbol) -> untyped
  def [](key)
    @data[key]
  end

  #--
  #: () -> Array[singleton(Riffer::Tool)]?
  def mcp_progressive_tools
    @data[:mcp_progressive_tools]
  end

  #--
  #: (Array[singleton(Riffer::Tool)]?) -> Array[singleton(Riffer::Tool)]?
  def mcp_progressive_tools=(value)
    valid = value.nil? || (
      value.is_a?(Array) &&
      value.all? { |tool| tool.is_a?(Class) && tool < Riffer::Tool }
    )
    unless valid
      raise Riffer::ArgumentError,
            "mcp_progressive_tools must be an Array of Riffer::Tool subclasses or nil, got #{value.class}"
    end
    @data[:mcp_progressive_tools] = value
  end

  #--
  #: () -> Array[singleton(Riffer::Tool)]?
  def discovered_tools
    @data[:discovered_tools]
  end

  #--
  #: (Array[singleton(Riffer::Tool)]?) -> Array[singleton(Riffer::Tool)]?
  def discovered_tools=(value)
    valid = value.nil? || (
      value.is_a?(Array) &&
      value.all? { |tool| tool.is_a?(Class) && tool < Riffer::Tool }
    )
    unless valid
      raise Riffer::ArgumentError,
            "discovered_tools must be an Array of Riffer::Tool subclasses or nil, got #{value.class}"
    end
    @data[:discovered_tools] = value
  end

  #--
  #: (Array[singleton(Riffer::Tool)]) -> Array[singleton(Riffer::Tool)]
  def discover_tools(tools)
    existing = @data[:discovered_tools] || []
    @data[:discovered_tools] = (existing + tools).uniq(&:name)
  end

  #--
  #: (*Symbol) -> untyped
  def dig(*keys)
    @data.dig(*keys)
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    @data.dup
  end
end
