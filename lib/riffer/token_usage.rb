# frozen_string_literal: true
# rbs_inline: enabled

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
  attr_reader :input_tokens #: Integer

  # Number of tokens in the output/response.
  attr_reader :output_tokens #: Integer

  # Number of tokens written to cache (Anthropic-specific).
  attr_reader :cache_creation_tokens #: Integer?

  # Number of tokens read from cache (Anthropic-specific).
  attr_reader :cache_read_tokens #: Integer?

  #: input_tokens: Integer
  #: output_tokens: Integer
  #: cache_creation_tokens: Integer? -- tokens written to cache
  #: cache_read_tokens: Integer? -- tokens read from cache
  #: return: void
  def initialize(input_tokens:, output_tokens:, cache_creation_tokens: nil, cache_read_tokens: nil)
    @input_tokens = input_tokens
    @output_tokens = output_tokens
    @cache_creation_tokens = cache_creation_tokens
    @cache_read_tokens = cache_read_tokens
  end

  # Returns the total number of tokens (input + output).
  #
  #: return: Integer
  def total_tokens
    input_tokens + output_tokens
  end

  # Combines two TokenUsage objects for cumulative tracking.
  #
  #: other: Riffer::TokenUsage
  #: return: Riffer::TokenUsage
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
  #: return: Hash[Symbol, Integer]
  def to_h
    hash = {input_tokens: input_tokens, output_tokens: output_tokens}
    hash[:cache_creation_tokens] = cache_creation_tokens if cache_creation_tokens
    hash[:cache_read_tokens] = cache_read_tokens if cache_read_tokens
    hash
  end

  private

  #: a: Integer?
  #: b: Integer?
  #: return: Integer?
  def add_nullable(a, b)
    return nil if a.nil? && b.nil?
    (a || 0) + (b || 0)
  end
end
