# frozen_string_literal: true

class TokenLimiterGuardrail < Riffer::Guardrail
  attr_reader :limit
  attr_reader :strategy

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
        metadata: { tokens: tokens, limit: limit },
      )
    else
      pass(response)
    end
  end

  private

  def estimate_tokens(text)
    # ~4 chars per English token; swap in a real tokenizer for production.
    (text.length / 4.0).ceil
  end

  def truncate_response(response)
    max_chars = limit * 4
    truncated = response.content[0, max_chars]
    truncated = truncated.sub(/\s+\S*\z/, "") if truncated.length < response.content.length
    Riffer::Messages::Assistant.new("#{truncated}...")
  end
end
