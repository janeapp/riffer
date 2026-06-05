# frozen_string_literal: true
# rbs_inline: enabled

# Typed value object wrapping the runtime context Hash held by a Riffer::Agent.
# Exposes typed +skills+, +token_usage+, and +mcp_progressive_tools+ accessors
# while preserving +#[]+ / +#dig+ for caller-provided keys.
class Riffer::Agent::Context
  # @rbs @data: Hash[Symbol, untyped]

  RESERVED_KEYS = [:skills, :token_usage, :mcp_progressive_tools].freeze #: Array[Symbol]

  # Builds a new context. The caller Hash is duped so later caller mutations
  # don't leak in. Raises Riffer::ArgumentError if it contains a reserved key.
  #--
  #: (?Hash[Symbol, untyped]) -> void
  def initialize(data = {})
    reserved = data.keys & RESERVED_KEYS
    if reserved.any?
      raise Riffer::ArgumentError,
        "Reserved keys cannot be passed in context: #{reserved.join(", ")}"
    end

    @data = data.dup
    @data[:skills] = nil
    @data[:token_usage] = nil
    @data[:mcp_progressive_tools] = nil
  end

  # The agent's resolved +Riffer::Skills::Context+, or +nil+ when skills
  # are not configured.
  #
  #--
  #: () -> Riffer::Skills::Context?
  def skills
    @data[:skills]
  end

  # Sets the resolved skills context. Raises Riffer::ArgumentError on an
  # invalid value.
  #--
  #: (Riffer::Skills::Context?) -> Riffer::Skills::Context?
  def skills=(value)
    unless value.nil? || value.is_a?(Riffer::Skills::Context)
      raise Riffer::ArgumentError,
        "skills must be a Riffer::Skills::Context or nil, got #{value.class}"
    end
    @data[:skills] = value
  end

  # The cumulative +Riffer::Providers::TokenUsage+ across every Run on this agent,
  # or +nil+ before the first response is recorded.
  #
  #--
  #: () -> Riffer::Providers::TokenUsage?
  def token_usage
    @data[:token_usage]
  end

  # Sets the cumulative token usage. Raises Riffer::ArgumentError on an invalid
  # value.
  #--
  #: (Riffer::Providers::TokenUsage?) -> Riffer::Providers::TokenUsage?
  def token_usage=(value)
    unless value.nil? || value.is_a?(Riffer::Providers::TokenUsage)
      raise Riffer::ArgumentError,
        "token_usage must be a Riffer::Providers::TokenUsage or nil, got #{value.class}"
    end
    @data[:token_usage] = value
  end

  # Hash-style read, preserved so tools can pull caller-provided keys via
  # <tt>context[:agent]</tt>.
  #--
  #: (Symbol) -> untyped
  def [](key)
    @data[key]
  end

  # Auth-wrapped MCP tool classes for progressive discovery, or +nil+.
  #--
  #: () -> Array[singleton(Riffer::Tool)]?
  def mcp_progressive_tools
    @data[:mcp_progressive_tools]
  end

  # Sets progressive MCP tools. Raises Riffer::ArgumentError on an invalid value.
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
  #: (*Symbol) -> untyped
  def dig(*keys)
    @data.dig(*keys)
  end

  # Returns a copy of the underlying Hash; mutating it does not affect this
  # context.
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    @data.dup
  end
end
