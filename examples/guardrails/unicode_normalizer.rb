# frozen_string_literal: true

class UnicodeNormalizerGuardrail < Riffer::Guardrail
  # C0/C1 controls, sparing tab, newline, and carriage return
  CONTROL_CHARS = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u0080-\u009F]/

  def process_input(messages, context:)
    normalized = messages.map { |msg| normalize_message(msg) }
    transform(normalized)
  end

  private

  def normalize_message(msg)
    return msg unless msg.respond_to?(:content) && msg.content

    cleaned = msg.content.
      unicode_normalize(:nfc).
      gsub(CONTROL_CHARS, "").
      gsub(/[[:space:]]+/, " ").
      strip

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
