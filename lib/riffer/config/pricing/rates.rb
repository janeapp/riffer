# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Pricing::Rates
  attr_reader :input #: Float # @dynamic input

  attr_reader :output #: Float # @dynamic output

  attr_reader :cache_read #: Float? # @dynamic cache_read

  attr_reader :cache_write #: Float? # @dynamic cache_write

  #--
  #: (input: Float, output: Float, ?cache_read: Float?, ?cache_write: Float?) -> void
  def initialize(input:, output:, cache_read: nil, cache_write: nil)
    @input = input
    @output = output
    @cache_read = cache_read
    @cache_write = cache_write
  end

  #--
  #: (input_tokens: Integer, output_tokens: Integer, ?cache_read_tokens: Integer?, ?cache_write_tokens: Integer?) -> Float
  def cost_for(input_tokens:, output_tokens:, cache_read_tokens: nil, cache_write_tokens: nil)
    read = cache_read_tokens || 0
    write = cache_write_tokens || 0
    uncached = input_tokens - read - write
    uncached = 0 if uncached.negative?

    per_million = (uncached * input) +
                  (read * (cache_read || input)) +
                  (write * (cache_write || input)) +
                  (output_tokens * output)
    per_million / 1_000_000.0
  end
end
