# frozen_string_literal: true
# rbs_inline: enabled

require "json"

module Riffer::Agent::StructuredOutput::Parser
  extend self

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def parse(content)
    extract(content)&.last
  end

  # Returns the JSON text that parsed, without any surrounding fence or prose,
  # alongside the parsed object.
  #--
  #: (String) -> [String, Hash[Symbol, untyped]]?
  def extract(content)
    parsed = parse_object(content)
    return [content, parsed] if parsed

    outermost_object(content)
  end

  private

  #--
  #: (String) -> [String, Hash[Symbol, untyped]]?
  def outermost_object(content)
    start = content.index("{")
    stop = content.rindex("}")
    return unless start && stop

    json = content[start..stop].to_s
    parsed = parse_object(json)
    [json, parsed] if parsed
  end

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def parse_object(json)
    parsed = JSON.parse(json, symbolize_names: true)
    parsed if parsed.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end
end
