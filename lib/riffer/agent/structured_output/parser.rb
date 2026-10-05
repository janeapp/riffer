# frozen_string_literal: true
# rbs_inline: enabled

require "json"

module Riffer::Agent::StructuredOutput::Parser
  extend self

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def parse(content)
    parse_object(content) || outermost_object(content)
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
  #: (String) -> Hash[Symbol, untyped]?
  def parse_object(json)
    parsed = JSON.parse(json, symbolize_names: true)
    parsed if parsed.is_a?(Hash)
  rescue JSON::ParserError
    nil
  end
end
