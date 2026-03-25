# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::TokenUsage
  attr_reader :input_tokens #: Integer
  attr_reader :output_tokens #: Integer
  attr_reader :cache_creation_tokens #: Integer?
  attr_reader :cache_read_tokens #: Integer?

  #: (input_tokens: Integer, output_tokens: Integer, ?cache_creation_tokens: Integer?, ?cache_read_tokens: Integer?) -> void
  def initialize(input_tokens:, output_tokens:, cache_creation_tokens: nil, cache_read_tokens: nil)
    @input_tokens = input_tokens
    @output_tokens = output_tokens
    @cache_creation_tokens = cache_creation_tokens
    @cache_read_tokens = cache_read_tokens
  end

  #: () -> Integer
  def total_tokens
    input_tokens + output_tokens
  end

  #: (Riffer::TokenUsage) -> Riffer::TokenUsage
  def +(other)
    Riffer::TokenUsage.new(
      input_tokens: input_tokens + other.input_tokens,
      output_tokens: output_tokens + other.output_tokens,
      cache_creation_tokens: add_nullable(cache_creation_tokens, other.cache_creation_tokens),
      cache_read_tokens: add_nullable(cache_read_tokens, other.cache_read_tokens)
    )
  end

  #: () -> Hash[Symbol, Integer]
  def to_h
    hash = {input_tokens: input_tokens, output_tokens: output_tokens}
    hash[:cache_creation_tokens] = cache_creation_tokens if cache_creation_tokens
    hash[:cache_read_tokens] = cache_read_tokens if cache_read_tokens
    hash
  end

  private

  #: (Integer?, Integer?) -> Integer?
  def add_nullable(a, b)
    return nil if a.nil? && b.nil?
    (a || 0) + (b || 0)
  end
end
