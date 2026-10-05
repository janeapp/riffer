# frozen_string_literal: true
# rbs_inline: enabled

require "json"
require "strscan"

module Riffer::Agent::StructuredOutput::Parser
  extend self

  # Bounds CPU time on pathological content such as long runs of unmatched braces.
  MAX_CANDIDATES = 20 #: Integer

  STRUCTURAL_CHAR = /[{}"]/ #: Regexp
  STRING_TAIL = /(?:[^"\\]++|\\.)*+"/m #: Regexp

  #--
  #: (String) -> untyped
  def parse(content)
    JSON.parse(content, symbolize_names: true)
  rescue JSON::ParserError => e
    # One native parse resolves a lone wrapped object without the slower scan.
    outermost_object(content) || recover(content) || raise(e)
  end

  private

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def outermost_object(content)
    start = content.index("{")
    stop = content.rindex("}")
    return unless start && stop

    parse_object(content[start..stop].to_s)
  end

  #--
  #: (String, ?Integer, ?Integer) -> Hash[Symbol, untyped]?
  def recover(content, from = 0, attempts = MAX_CANDIDATES)
    # Byte offsets, to line up with StringScanner#pos in closing_brace.
    start = content.byteindex("{", from)
    return if start.nil? || attempts.zero?

    stop = closing_brace(content, start)
    return recover(content, start + 1, attempts - 1) unless stop

    # Resume after the whole span so a malformed object never yields one of
    # its nested objects.
    parse_object(content.byteslice(start..stop).to_s) || recover(content, stop + 1, attempts - 1)
  end

  #--
  #: (String, Integer) -> Integer?
  def closing_brace(content, start)
    scanner = StringScanner.new(content)
    scanner.pos = start
    depth = 0

    while scanner.skip_until(STRUCTURAL_CHAR)
      case scanner.matched
      when "{"
        depth += 1
      when "}"
        depth -= 1
        return scanner.pos - 1 if depth.zero?
      else
        return unless scanner.skip(STRING_TAIL)
      end
    end
  end

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def parse_object(span)
    JSON.parse(span, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end
end
