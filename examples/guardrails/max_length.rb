# frozen_string_literal: true

# Max Length Guardrail
#
# Blocks messages or responses that exceed a maximum character length.
#
# Usage:
#
#   class MyAgent < Riffer::Agent
#     model "openai/gpt-4o"
#
#     # Block input messages over 1000 characters
#     guardrail :before, with: MaxLengthGuardrail, max: 1000
#
#     # Block responses over 5000 characters
#     guardrail :after, with: MaxLengthGuardrail, max: 5000
#
#     # Apply to both with default limit (10,000 characters)
#     guardrail :around, with: MaxLengthGuardrail
#   end
#
class MaxLengthGuardrail < Riffer::Guardrail
  DEFAULT_MAX = 10_000

  attr_reader :max

  def initialize(max: DEFAULT_MAX)
    super()
    @max = max
  end

  def process_input(messages, context:)
    messages.each do |msg|
      next unless msg.respond_to?(:content)
      next if msg.content.nil?

      if msg.content.length > max
        return block(
          "Message exceeds maximum length of #{max} characters",
          metadata: {length: msg.content.length, max: max}
        )
      end
    end
    pass(messages)
  end

  def process_output(response, messages:, context:)
    return pass(response) unless response.respond_to?(:content)
    return pass(response) if response.content.nil?

    if response.content.length > max
      block(
        "Response exceeds maximum length of #{max} characters",
        metadata: {length: response.content.length, max: max}
      )
    else
      pass(response)
    end
  end
end
