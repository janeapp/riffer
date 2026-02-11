# frozen_string_literal: true
# rbs_inline: enabled

# A guardrail that blocks messages exceeding a maximum character length.
#
# Demonstrates the guardrail pattern with a simple, practical use case.
#
#   guardrail :before, with: Riffer::Guardrails::MaxLength, max: 1000
#   guardrail :after, with: Riffer::Guardrails::MaxLength, max: 5000
class Riffer::Guardrails::MaxLength < Riffer::Guardrail
  DEFAULT_MAX = 10_000 #: Integer

  # The maximum allowed character length.
  attr_reader :max #: Integer

  # Creates a new max length guardrail.
  #
  # +max+ - maximum allowed characters (default: 10_000).
  #
  #: (?max: Integer) -> void
  def initialize(max: DEFAULT_MAX)
    super()
    @max = max
  end

  # Blocks if any user message exceeds the max length.
  #
  # +messages+ - the input messages.
  # +context+ - optional context.
  #
  #: (Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
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

  # Blocks if response exceeds the max length.
  #
  # +response+ - the LLM response.
  # +messages+ - the conversation messages.
  # +context+ - optional context.
  #
  #: (Riffer::Messages::Assistant, messages: Array[Riffer::Messages::Base], context: untyped) -> Riffer::Guardrails::Result
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
