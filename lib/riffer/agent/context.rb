# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Agent::Context
  # @rbs @data: Hash[Symbol, untyped]

  RESERVED_KEYS = %i[skills token_usage].freeze #: Array[Symbol]

  # Raises Riffer::ArgumentError if +data+ contains a reserved key.
  #--
  #: (?Hash[Symbol, untyped]) -> void
  def initialize(data = {})
    reserved = data.keys & RESERVED_KEYS
    if reserved.any?
      raise Riffer::ArgumentError,
            "Reserved keys cannot be passed in context: #{reserved.join(', ')}"
    end
    warn_deferred_tools_key if data.key?(:deferred_tools)

    @data = data.dup
    @data[:skills] = nil
    @data[:token_usage] = nil
    @deferred_tools = nil
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

  attr_reader :deferred_tools #: Array[singleton(Riffer::Tool)]? # @dynamic deferred_tools

  #--
  #: (Array[singleton(Riffer::Tool)]?) -> Array[singleton(Riffer::Tool)]?
  def deferred_tools=(value)
    valid = value.nil? || (value.is_a?(Array) && value.all? { |tool| tool.is_a?(Class) && tool < Riffer::Tool })
    unless valid
      raise Riffer::ArgumentError,
            "deferred_tools must be an Array of Riffer::Tool subclasses or nil, got #{value.class}"
    end
    @deferred_tools = value
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

  private

  #--
  #: () -> void
  def warn_deferred_tools_key
    Riffer::Deprecation.warn(
      id: :context_deferred_tools_key,
      message: "Passing :deferred_tools in context: is deprecated; a future breaking release reserves the key " \
               "for the agent's deferred tools (context.deferred_tools). Rename the key.",
    )
  end
end
