# frozen_string_literal: true
# rbs_inline: enabled

# Typed value object wrapping the runtime context Hash held by a
# Riffer::Agent. Exposes first-class accessors for the framework-managed
# entries — +skills+, +token_usage+, and +mcp_progressive_tools+ — and
# preserves +#[]+ / +#dig+ reads so tools (which receive +context:+ as a
# keyword) keep working with both built-in and caller-provided keys.
#
# Reserved keys (+:skills+, +:token_usage+, +:mcp_progressive_tools+)
# cannot be set by the caller at construction; they are owned by Riffer
# and written through the typed setters. Type invariants are enforced on
# write — +skills+ must be a +Riffer::Skills::Context+ (or nil);
# +token_usage+ must be a +Riffer::Providers::TokenUsage+ (or nil);
# +mcp_progressive_tools+ must be an Array of +Riffer::Tool+ subclasses
# (or nil).
#
#   context = Riffer::Agent::Context.new(user_id: 42)
#   context[:user_id]    # => 42
#   context.skills       # => nil
#   context.token_usage  # => nil
#
class Riffer::Agent::Context
  # @rbs @data: Hash[Symbol, untyped]

  # Keys reserved for framework use. Passing any of these to the
  # constructor raises +Riffer::ArgumentError+.
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
  # Raises Riffer::ArgumentError if +value+ is neither +nil+ nor an Array
  # of +Riffer::Tool+ subclasses.
  #
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
