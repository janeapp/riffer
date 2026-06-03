# frozen_string_literal: true
# rbs_inline: enabled

# Typed value object wrapping the runtime context Hash held by a Riffer::Agent.
# Exposes typed +skills+ / +token_usage+ accessors while preserving +#[]+ /
# +#dig+ for caller-provided keys.
class Riffer::Agent::Context
  # @rbs @data: Hash[Symbol, untyped]

  RESERVED_KEYS = [:skills, :token_usage].freeze #: Array[Symbol]

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

  # The per-agent set of auth-wrapped MCP tool classes available during a
  # progressive run, or +nil+ when no progressive +use_mcp+ resolved any tools.
  #
  # Read by +Riffer::Mcp::SearchTool+ and +Riffer::Mcp::CallTool+.
  #
  #--
  #: () -> Array[singleton(Riffer::Tool)]?
  def mcp_progressive_tools
    @data[:mcp_progressive_tools]
  end

  # Sets the progressive MCP tools. Called by +Riffer::Agent+ during
  # construction when a progressive +use_mcp+ resolves at least one tool.
  #
  #--
  #: (Array[singleton(Riffer::Tool)]?) -> Array[singleton(Riffer::Tool)]?
  def mcp_progressive_tools=(value)
    @data[:mcp_progressive_tools] = value
  end

  # Hash-style dig. Preserved for tools using
  # <tt>context&.dig(:user_id)</tt>.
  #
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
