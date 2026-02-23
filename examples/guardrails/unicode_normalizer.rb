# frozen_string_literal: true

# Unicode Normalizer Guardrail
#
# Normalizes input text to NFC form, strips control characters,
# collapses consecutive whitespace, and trims leading/trailing whitespace.
#
# Usage:
#
#   class MyAgent < Riffer::Agent
#     model "openai/gpt-4o"
#
#     guardrail :before, with: UnicodeNormalizerGuardrail
#   end
#
class UnicodeNormalizerGuardrail < Riffer::Guardrail
  # Unicode control characters (C0/C1) except common whitespace (tab, newline, carriage return)
  CONTROL_CHARS = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u0080-\u009F]/

  def process_input(messages, context:)
    normalized = messages.map { |msg| normalize_message(msg) }
    transform(normalized)
  end

  private

  def normalize_message(msg)
    return msg unless msg.respond_to?(:content) && msg.content

    cleaned = msg.content
      .unicode_normalize(:nfc)
      .gsub(CONTROL_CHARS, "")
      .gsub(/[[:space:]]+/, " ")
      .strip

    rebuild_message(msg, cleaned)
  end

  def rebuild_message(msg, content)
    case msg
    when Riffer::Messages::User
      Riffer::Messages::User.new(content)
    when Riffer::Messages::System
      Riffer::Messages::System.new(content)
    else
      msg
    end
  end
end
