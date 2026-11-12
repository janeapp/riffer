# frozen_string_literal: true
# rbs_inline: enabled

require "json"

module Riffer::Providers::DeferredToolGateway
  extend self

  # +deferred_tools+ are the ones the gateway carries for the request. With none there is no gateway, and every
  # function here returns its input.
  #--
  #: (Array[Riffer::Messages::Base], Array[singleton(Riffer::Tool)]) -> Array[Riffer::Messages::Base]
  def wrap_messages(messages, deferred_tools)
    return messages if deferred_tools.empty?

    deferred_names = deferred_tools.map(&:name)
    messages.map do |message|
      case message
      when Riffer::Messages::Assistant then wrap_assistant(message, deferred_names)
      when Riffer::Messages::Tool then wrap_tool_result(message, deferred_tools)
      else message
      end
    end
  end

  #--
  #: (Array[Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart], Array[singleton(Riffer::Tool)]) -> Array[Riffer::Messages::Assistant::TextPart | Riffer::Messages::Assistant::ReasoningPart | Riffer::Messages::Assistant::ToolCall | Riffer::Messages::Assistant::ServerToolPart]
  def unwrap_parts(parts, deferred_tools)
    return parts if deferred_tools.empty?

    parts.map { |part| part.is_a?(Riffer::Messages::Assistant::ToolCall) ? unwrap_tool_call(part, deferred_tools) : part }
  end

  # A gateway call without a string name and string arguments stays a call to the gateway, which is never one of
  # the agent's tools, so the model gets an +:unknown_tool+ error result.
  #--
  #: (Riffer::Messages::Assistant::ToolCall, Array[singleton(Riffer::Tool)]) -> Riffer::Messages::Assistant::ToolCall
  def unwrap_tool_call(tool_call, deferred_tools)
    return tool_call unless tool_call.name == Tool.name

    call = parse_gateway_arguments(tool_call.arguments)
    return tool_call unless call

    name, arguments = call
    Riffer::Messages::Assistant::ToolCall.new(
      call_id: tool_call.call_id,
      # The model may name a loaded tool in the wire-safe form it sees on the agent's other tools.
      name: Riffer::Wire.decode_tool_name(name, tools: deferred_tools),
      arguments: arguments,
    )
  end

  #--
  #: (Riffer::Providers::_EventSink, Array[singleton(Riffer::Tool)]) -> Riffer::Providers::_EventSink
  def unwrapping_sink(sink, deferred_tools)
    deferred_tools.empty? ? sink : Sink.new(sink, deferred_tools: deferred_tools)
  end

  private

  #--
  #: (String) -> [String, String]?
  def parse_gateway_arguments(arguments)
    parsed = JSON.parse(arguments)
    return unless parsed.is_a?(Hash)

    name = parsed["name"]
    tool_arguments = parsed["arguments"]
    [name, tool_arguments] if name.is_a?(String) && tool_arguments.is_a?(String)
  rescue JSON::ParserError
    nil
  end

  #--
  #: (Riffer::Messages::Assistant, Array[String]) -> Riffer::Messages::Assistant
  def wrap_assistant(message, deferred_names)
    return message if message.tool_calls.none? { |tool_call| deferred_names.include?(tool_call.name) }

    Riffer::Messages::Assistant.new(
      id: message.id,
      parts: message.parts.map do |part|
        part.is_a?(Riffer::Messages::Assistant::ToolCall) ? wrap_tool_call(part, deferred_names) : part
      end,
      token_usage: message.token_usage,
      structured_output: message.structured_output,
      finish_reason: message.finish_reason,
      finish_reason_raw: message.finish_reason_raw,
    )
  end

  #--
  #: (Riffer::Messages::Assistant::ToolCall, Array[String]) -> Riffer::Messages::Assistant::ToolCall
  def wrap_tool_call(tool_call, deferred_names)
    return tool_call unless deferred_names.include?(tool_call.name)

    Riffer::Messages::Assistant::ToolCall.new(
      call_id: tool_call.call_id,
      name: Tool.name,
      arguments: JSON.generate({ name: tool_call.name, arguments: tool_call.arguments }),
    )
  end

  # A result for a deferred tool is renamed along with its call, since Gemini sends the name with a function
  # response and rejects one that names no declared function.
  #--
  #: (Riffer::Messages::Tool, Array[singleton(Riffer::Tool)]) -> Riffer::Messages::Tool
  def wrap_tool_result(message, deferred_tools)
    loaded = loaded_deferred_tools(message, deferred_tools)
    deferred_call = deferred_tools.any? { |tool| tool.name == message.name }
    return message if loaded.empty? && !deferred_call

    Riffer::Messages::Tool.new(
      loaded.empty? ? message.content : [message.content, describe_loaded_tools(loaded)].reject(&:empty?).join("\n\n"),
      tool_call_id: message.tool_call_id,
      name: deferred_call ? Tool.name : message.name,
      id: message.id,
      error: message.error,
      error_type: message.error_type,
      loaded_tools: message.loaded_tools,
    )
  end

  #--
  #: (Riffer::Messages::Tool, Array[singleton(Riffer::Tool)]) -> Array[singleton(Riffer::Tool)]
  def loaded_deferred_tools(message, deferred_tools)
    return [] if message.error?

    deferred_tools.select { |tool| message.loaded_tools.include?(tool.name) }
  end

  # Deterministic, so an earlier tool result reads the same on every request and the prompt cache holds.
  #--
  #: (Array[singleton(Riffer::Tool)]) -> String
  def describe_loaded_tools(tools)
    entries = tools.map do |tool|
      { name: tool.name, description: tool.description, parameters: tool.parameters_schema }
    end
    [loaded_tools_header, JSON.generate(entries)].join("\n\n")
  end

  # Names the gateway as the model sees it in its tool list; models copy a raw namespaced name into calls verbatim.
  #--
  #: () -> String
  def loaded_tools_header
    "These tools are now loaded. They are not in your tool list, so calling one by its own name fails. Call each " \
      "one through the #{Riffer::Wire.encode_tool_name(Tool.name)} tool: set name to the tool's name exactly as " \
      "written below, and set arguments to a string holding its arguments as a JSON object that matches its " \
      "parameters. Use \"{}\" as arguments for a tool without parameters."
  end
end
