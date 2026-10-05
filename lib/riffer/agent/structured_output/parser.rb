# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Without native constrained decoding, models often wrap a valid object in code
# fences, prose, or markdown despite instructions, so a strict parse alone
# rejects correct answers.
module Riffer::Agent::StructuredOutput::Parser
  extend self

  # Caps recovery on pathological content such as a long run of unmatched
  # braces, where every candidate scans to the end of the string.
  MAX_CANDIDATES = 20 #: Integer

  #--
  #: (String) -> untyped
  def parse(content)
    JSON.parse(content, symbolize_names: true)
  rescue JSON::ParserError => e
    recover(content) || raise(e)
  end

  private

  #--
  #: (String, ?Integer, ?Integer) -> Hash[Symbol, untyped]?
  def recover(content, from = 0, attempts = MAX_CANDIDATES)
    start = content.index("{", from)
    return if start.nil? || attempts.zero?

    stop = closing_brace(content, start)
    return recover(content, start + 1, attempts - 1) unless stop

    # Resume after the whole span so a malformed object never yields one of
    # its nested objects.
    parse_object(content[start..stop].to_s) || recover(content, stop + 1, attempts - 1)
  end

  #--
  #: (String, Integer) -> Integer?
  def closing_brace(content, start)
    depth = 0
    in_string = false
    escaped = false

    content[start..].to_s.each_char.with_index(start) do |char, index|
      if in_string
        if escaped
          escaped = false
        elsif char == "\\"
          escaped = true
        elsif char == '"'
          in_string = false
        end
      elsif char == '"'
        in_string = true
      elsif char == "{"
        depth += 1
      elsif char == "}"
        depth -= 1
        return index if depth.zero?
      end
    end

    nil
  end

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def parse_object(span)
    JSON.parse(span, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end
end
