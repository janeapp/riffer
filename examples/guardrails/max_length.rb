# frozen_string_literal: true

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
          metadata: { length: msg.content.length, max: max },
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
        metadata: { length: response.content.length, max: max },
      )
    else
      pass(response)
    end
  end
end
