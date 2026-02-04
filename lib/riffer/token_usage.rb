# frozen_string_literal: true

# Represents token usage data from an LLM API call.
#
# Tracks input tokens, output tokens, and optional cache statistics.
#
#   token_usage = Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50)
#   token_usage.total_tokens  # => 150
#
#   combined = token_usage1 + token_usage2  # Combine multiple token usage objects
#
class Riffer::TokenUsage
  # Number of tokens in the input/prompt.
  #
  # Returns Integer.
  attr_reader :input_tokens

  # Number of tokens in the output/response.
  #
  # Returns Integer.
  attr_reader :output_tokens

  # Number of tokens written to cache (Anthropic-specific).
  #
  # Returns Integer or nil.
  attr_reader :cache_creation_tokens

  # Number of tokens read from cache (Anthropic-specific).
  #
  # Returns Integer or nil.
  attr_reader :cache_read_tokens

  # Creates a new TokenUsage instance.
  #
  # input_tokens:: Integer - number of input tokens
  # output_tokens:: Integer - number of output tokens
  # cache_creation_tokens:: Integer or nil - tokens written to cache
  # cache_read_tokens:: Integer or nil - tokens read from cache
  def initialize(input_tokens:, output_tokens:, cache_creation_tokens: nil, cache_read_tokens: nil)
    @input_tokens = input_tokens
    @output_tokens = output_tokens
    @cache_creation_tokens = cache_creation_tokens
    @cache_read_tokens = cache_read_tokens
  end

  # Returns the total number of tokens (input + output).
  #
  # Returns Integer.
  def total_tokens
    input_tokens + output_tokens
  end

  # Combines two TokenUsage objects for cumulative tracking.
  #
  # other:: Riffer::TokenUsage - another token usage object to combine with
  #
  # Returns Riffer::TokenUsage - a new TokenUsage with summed values.
  def +(other)
    Riffer::TokenUsage.new(
      input_tokens: input_tokens + other.input_tokens,
      output_tokens: output_tokens + other.output_tokens,
      cache_creation_tokens: add_nullable(cache_creation_tokens, other.cache_creation_tokens),
      cache_read_tokens: add_nullable(cache_read_tokens, other.cache_read_tokens)
    )
  end

  # Converts the token usage to a hash representation.
  #
  # Cache tokens are omitted if nil.
  #
  # Returns Hash.
  def to_h
    hash = {input_tokens: input_tokens, output_tokens: output_tokens}
    hash[:cache_creation_tokens] = cache_creation_tokens if cache_creation_tokens
    hash[:cache_read_tokens] = cache_read_tokens if cache_read_tokens
    hash
  end

  private

  def add_nullable(a, b)
    return nil if a.nil? && b.nil?
    (a || 0) + (b || 0)
  end
end
