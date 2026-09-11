# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Serializes riffer messages into the GenAI semconv JSON message structure
# for opt-in span content capture. File parts become metadata-only stubs —
# bytes and URLs never reach a span attribute.
module Riffer::Tracing::Capture # :nodoc: all
  extend self

  #--
  #: (Array[Riffer::Messages::Base]) -> String
  def input_messages(messages)
    JSON.generate(messages.filter_map { |message| convert_message(message) })
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> String?
  def system_instructions(messages)
    parts = messages.grep(Riffer::Messages::System).map { |message| text_part(message.content) }
    return nil if parts.empty?

    JSON.generate(parts)
  end

  #--
  #: (content: String?, tool_calls: Array[Riffer::Messages::Assistant::ToolCall], finish_reason: Symbol?, ?reasoning: Array[Riffer::Messages::Assistant::Reasoning]) -> String
  def output_messages(content:, tool_calls:, finish_reason:, reasoning: [])
    message = { role: "assistant", parts: assistant_parts(content, tool_calls, reasoning) } #: Hash[Symbol, untyped]
    message[:finish_reason] = finish_reason if finish_reason
    JSON.generate([message])
  end

  private

  #--
  #: (Riffer::Messages::Base) -> Hash[Symbol, untyped]?
  def convert_message(message)
    case message
    when Riffer::Messages::User
      parts = [text_part(message.content)] #: Array[Hash[Symbol, untyped]]
      parts.concat(message.files.map { |file| file_part(file) })
      { role: "user", parts: parts }
    when Riffer::Messages::Assistant
      { role: "assistant", parts: assistant_parts(message.content, message.tool_calls, message.reasoning) }
    when Riffer::Messages::Tool
      { role: "tool", parts: [{ type: "tool_call_response", id: message.tool_call_id, response: message.content }] }
    end
  end

  #--
  #: (String?, Array[Riffer::Messages::Assistant::ToolCall], ?Array[Riffer::Messages::Assistant::Reasoning]) -> Array[Hash[Symbol, untyped]]
  def assistant_parts(content, tool_calls, reasoning = [])
    parts = [] #: Array[Hash[Symbol, untyped]]
    # A block's signature or redacted payload is an opaque credential, never
    # span content — only readable reasoning text is captured.
    reasoning.each do |block|
      text = block.text
      parts << reasoning_part(text) if text && !text.empty?
    end
    parts << text_part(content) if content && !content.empty?
    parts.concat(tool_calls.map { |tool_call| tool_call_part(tool_call) })
    parts
  end

  #--
  #: (String?) -> Hash[Symbol, untyped]
  def text_part(content)
    { type: "text", content: content }
  end

  #--
  #: (String) -> Hash[Symbol, untyped]
  def reasoning_part(content)
    { type: "reasoning", content: content }
  end

  #--
  #: (Riffer::Messages::Assistant::ToolCall) -> Hash[Symbol, untyped]
  def tool_call_part(tool_call)
    { type: "tool_call", id: tool_call.call_id, name: tool_call.name, arguments: parse_arguments(tool_call.arguments) }
  end

  #--
  #: (Riffer::Messages::FilePart) -> Hash[Symbol, untyped]
  def file_part(file)
    part = { type: "file", media_type: file.media_type } #: Hash[Symbol, untyped]
    part[:name] = file.filename if file.filename
    part
  end

  # Semconv's tool_call part carries arguments as a JSON object; riffer holds
  # them as a string — parse so the captured payload isn't double-encoded.
  #--
  #: (untyped) -> untyped
  def parse_arguments(arguments)
    return arguments unless arguments.is_a?(String)

    JSON.parse(arguments)
  rescue JSON::ParserError
    arguments
  end
end
