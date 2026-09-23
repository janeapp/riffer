# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::TokenUsage
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Providers::TokenUsage)) -> Riffer::Providers::TokenUsage
  def self.from_hash(usage)
    return usage if usage.is_a?(Riffer::Providers::TokenUsage)

    new(
      input_tokens: usage[:input_tokens],
      output_tokens: usage[:output_tokens],
      cache_write_tokens: usage[:cache_write_tokens],
      cache_read_tokens: usage[:cache_read_tokens],
      cost: usage[:cost],
    )
  end

  # Normalized across providers: includes cache reads and writes.
  attr_reader :input_tokens #: Integer # @dynamic input_tokens

  # Includes reasoning/thinking tokens.
  attr_reader :output_tokens #: Integer # @dynamic output_tokens

  # Subset of +input_tokens+.
  attr_reader :cache_write_tokens #: Integer? # @dynamic cache_write_tokens

  # Subset of +input_tokens+.
  attr_reader :cache_read_tokens #: Integer? # @dynamic cache_read_tokens

  # For observability, not billing.
  attr_reader :cost #: Float? # @dynamic cost

  #--
  #: (input_tokens: Integer, output_tokens: Integer, ?cache_write_tokens: Integer?, ?cache_read_tokens: Integer?, ?cost: Float?) -> void
  def initialize(input_tokens:, output_tokens:, cache_write_tokens: nil, cache_read_tokens: nil, cost: nil)
    @input_tokens = input_tokens
    @output_tokens = output_tokens
    @cache_write_tokens = cache_write_tokens
    @cache_read_tokens = cache_read_tokens
    @cost = cost
  end

  #--
  #: () -> Integer
  def total_tokens
    input_tokens + output_tokens
  end

  #--
  #: (Riffer::Providers::TokenUsage) -> Riffer::Providers::TokenUsage
  def +(other)
    Riffer::Providers::TokenUsage.new(
      input_tokens: input_tokens + other.input_tokens,
      output_tokens: output_tokens + other.output_tokens,
      cache_write_tokens: add_nullable(cache_write_tokens, other.cache_write_tokens),
      cache_read_tokens: add_nullable(cache_read_tokens, other.cache_read_tokens),
      cost: add_cost(cost, other.cost),
    )
  end

  #--
  #: () -> Hash[Symbol, (Integer | Float)]
  def to_h
    hash = { input_tokens: input_tokens, output_tokens: output_tokens } #: Hash[Symbol, (Integer | Float)]
    hash[:cache_write_tokens] = cache_write_tokens if cache_write_tokens
    hash[:cache_read_tokens] = cache_read_tokens if cache_read_tokens
    hash[:cost] = cost if cost
    hash
  end

  private

  #--
  #: (Integer?, Integer?) -> Integer?
  def add_nullable(left, right)
    return nil if left.nil? && right.nil?

    (left || 0) + (right || 0)
  end

  # nil is absorbing, not zero: one unpriced call makes the run total nil
  # rather than silently under-reporting.
  #--
  #: (Float?, Float?) -> Float?
  def add_cost(left, right)
    return nil if left.nil? || right.nil?

    left + right
  end
end
