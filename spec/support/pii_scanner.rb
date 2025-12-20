# frozen_string_literal: true

class PiiScanner < Riffer::Guardrails::Base
  def process_input(content)
    content.gsub(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, "[REDACTED]")
  end
end
