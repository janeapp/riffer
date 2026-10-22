# frozen_string_literal: true
# rbs_inline: enabled

require "json"

module Riffer::Wire
  extend self

  TOOL_NAME_SEPARATOR = "__" #: String

  #--
  #: (String) -> String
  def encode_tool_name(name)
    name.gsub("/", TOOL_NAME_SEPARATOR)
  end

  #--
  #: (String, tools: Array[singleton(Riffer::Tool)]) -> String
  def decode_tool_name(wire_name, tools:)
    tool = tools.find { |t| encode_tool_name(t.name) == wire_name }
    tool ? tool.name : wire_name
  end

  #--
  #: (String) -> Hash[String, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.empty?

    JSON.parse(arguments)
  end
end
