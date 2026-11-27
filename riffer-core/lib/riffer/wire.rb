# frozen_string_literal: true
# rbs_inline: enabled

require "json"

module Riffer::Wire
  extend self

  TOOL_NAME_SEPARATOR = "__" #: String

  # The tool name pattern Anthropic, Bedrock and OpenAI require.
  TOOL_NAME_PATTERN = /\A[a-zA-Z0-9_-]{1,64}\z/ #: Regexp
  private_constant :TOOL_NAME_PATTERN

  INVALID_TOOL_NAME = "invalid_tool_name" #: String

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

  # A model can emit a tool call with a name that isn't a valid tool name or arguments that aren't a JSON object.
  # Every later request replaying it as-is is rejected, by the provider or while riffer builds it, so the call goes
  # out as INVALID_TOOL_NAME or with +{}+ arguments, so the model still sees the error it got.
  #--
  #: (Array[Riffer::Messages::Base]) -> Array[Riffer::Messages::Base]
  def replayable_messages(messages)
    messages.map do |message|
      case message
      when Riffer::Messages::Assistant then replayable_assistant(message)
      when Riffer::Messages::Tool then replayable_tool_result(message)
      else message
      end
    end
  end

  private

  #--
  #: (Riffer::Messages::Assistant) -> Riffer::Messages::Assistant
  def replayable_assistant(message)
    parts = message.parts.map do |part|
      part.is_a?(Riffer::Messages::Assistant::ToolCall) ? replayable_tool_call(part) : part
    end
    parts == message.parts ? message : message.with_parts(parts)
  end

  #--
  #: (Riffer::Messages::Assistant::ToolCall) -> Riffer::Messages::Assistant::ToolCall
  def replayable_tool_call(tool_call)
    name = replayable_tool_name(tool_call.name)
    arguments = tool_arguments_object?(tool_call.arguments) ? tool_call.arguments : "{}"
    Riffer::Messages::Assistant::ToolCall.new(call_id: tool_call.call_id, name: name, arguments: arguments)
  end

  # The result is renamed with its call, staying paired for the providers that send a result's name.
  #--
  #: (Riffer::Messages::Tool) -> Riffer::Messages::Tool
  def replayable_tool_result(message)
    name = replayable_tool_name(message.name)
    name == message.name ? message : message.with(name: name)
  end

  #--
  #: (String) -> String
  def replayable_tool_name(name)
    TOOL_NAME_PATTERN.match?(encode_tool_name(name)) ? name : INVALID_TOOL_NAME
  end

  #--
  #: (String) -> bool
  def tool_arguments_object?(arguments)
    parse_tool_arguments(arguments).is_a?(Hash)
  rescue JSON::ParserError
    false
  end
end
