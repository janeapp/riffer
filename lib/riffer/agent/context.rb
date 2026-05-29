# frozen_string_literal: true
# rbs_inline: enabled

# Typed value object wrapping the runtime context Hash held by a
# Riffer::Agent. Exposes first-class accessors for the framework-managed
# entries — +skills+ and +token_usage+ — and preserves +#[]+ / +#dig+
# reads so tools (which receive +context:+ as a keyword) keep working
# with both built-in and caller-provided keys.
#
# Reserved keys (+:skills+, +:token_usage+) cannot be set by the caller
# at construction; they are owned by Riffer and written through the typed
# setters. Type invariants are enforced on write — +skills+ must be a
# +Riffer::Skills::Context+ (or nil); +token_usage+ must be a
# +Riffer::Providers::TokenUsage+ (or nil).
#
#   context = Riffer::Agent::Context.new(user_id: 42)
#   context[:user_id]    # => 42
#   context.skills       # => nil
#   context.token_usage  # => nil
#
class Riffer::Agent::Context
  # Keys reserved for framework use. Passing any of these to the
  # constructor raises +Riffer::ArgumentError+.
  RESERVED_KEYS = [:skills, :token_usage].freeze #: Array[Symbol]

  # Builds a new context.
  #
  # [data] caller-provided Hash passed as <tt>Agent.new(context:)</tt>.
  #        Duped before storage so caller mutations do not affect the
  #        agent. Must not contain any +RESERVED_KEYS+.
  #
  # Raises Riffer::ArgumentError when +data+ contains a reserved key.
  #
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

  # Sets the resolved skills context. Called once by +Riffer::Agent+
  # during construction.
  #
  # Raises Riffer::ArgumentError if +value+ is neither +nil+ nor a
  # +Riffer::Skills::Context+.
  #
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

  # Sets the cumulative token usage. Called by +Riffer::Agent::Run+ after
  # each LLM response.
  #
  # Raises Riffer::ArgumentError if +value+ is neither +nil+ nor a
  # +Riffer::Providers::TokenUsage+.
  #
  #--
  #: (Riffer::Providers::TokenUsage?) -> Riffer::Providers::TokenUsage?
  def token_usage=(value)
    unless value.nil? || value.is_a?(Riffer::Providers::TokenUsage)
      raise Riffer::ArgumentError,
        "token_usage must be a Riffer::Providers::TokenUsage or nil, got #{value.class}"
    end
    @data[:token_usage] = value
  end

  # Hash-style read. Preserved so downstream tool runtimes pulling
  # caller-provided keys via <tt>context[:agent]</tt> or
  # <tt>context[:tenant]</tt> keep working unchanged.
  #
  #--
  #: (Symbol) -> untyped
  def [](key)
    @data[key]
  end

  # Hash-style dig. Preserved for tools using
  # <tt>context&.dig(:user_id)</tt>.
  #
  #--
  #: (*Symbol) -> untyped
  def dig(*keys)
    @data.dig(*keys)
  end

  # Returns a copy of the underlying Hash. Mutating the result does not
  # affect this context.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    @data.dup
  end
end
