# frozen_string_literal: true

# Token Limiter Guardrail
#
# Manages output token limits with configurable strategies.
#
# Strategies:
#   :truncate - Truncates the response to fit within the token limit
#   :block    - Blocks the response entirely if it exceeds the limit
#
# Usage:
#
#   class MyAgent < Riffer::Agent
#     model "openai/gpt-4o"
#
#     # Truncate responses over 500 tokens
#     guardrail :after, with: TokenLimiterGuardrail, limit: 500
#
#     # Block responses over 1000 tokens
#     guardrail :after, with: TokenLimiterGuardrail, limit: 1000, strategy: :block
#   end
#
class TokenLimiterGuardrail < Riffer::Guardrail
  attr_reader :limit, :strategy

  def initialize(limit:, strategy: :truncate)
    super()
    @limit = limit
    @strategy = strategy
  end

  def process_output(response, messages:, context:)
    return pass(response) unless response.respond_to?(:content)
    return pass(response) if response.content.nil?

    tokens = estimate_tokens(response.content)
    return pass(response) if tokens <= limit

    case strategy
    when :truncate
      transform(truncate_response(response))
    when :block
      block(
        "Response exceeds token limit of #{limit}",
        metadata: {tokens: tokens, limit: limit}
      )
    else
      pass(response)
    end
  end

  private

  def estimate_tokens(text)
    # Rough approximation: ~4 characters per token for English text.
    # Replace with a proper tokenizer for production use.
    (text.length / 4.0).ceil
  end

  def truncate_response(response)
    max_chars = limit * 4
    truncated = response.content[0, max_chars]
    # Cut at the last word boundary to avoid mid-word truncation
    truncated = truncated.sub(/\s+\S*\z/, "") if truncated.length < response.content.length
    Riffer::Messages::Assistant.new(truncated + "...")
  end
end
