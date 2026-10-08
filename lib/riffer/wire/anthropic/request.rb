# frozen_string_literal: true
# rbs_inline: enabled

require "json"

module Riffer::Wire::Anthropic::Request
  extend self

  WEB_SEARCH_TOOL_TYPE = "web_search_20250305" #: String

  # The Messages API body without +model+, which some transports carry in the
  # URL instead.
  #--
  #: (Array[Riffer::Messages::Base], Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build(messages, options)
    partitioned_messages = partition_messages(messages)
    tools = options[:tools]
    structured_output = options[:structured_output]
    web_search = options[:web_search]
    tags = options[:tags] || {}

    max_tokens = options.fetch(:max_tokens, 4096)

    params = {
      messages: partitioned_messages[:conversation],
      max_tokens: max_tokens,
      **options.except(:tools, :max_tokens, :structured_output, :web_search, :tags),
    } #: Hash[Symbol, untyped]

    params[:system] = partitioned_messages[:system] if partitioned_messages[:system]

    # Anthropic's only request-metadata field is metadata.user_id (opaque, no
    # PII); all other tags survive only on spans.
    user_id = tags["user_id"]
    params[:metadata] = { user_id: user_id } if user_id

    anthropic_tools = [] #: Array[Hash[Symbol, untyped]]
    anthropic_tools.concat(tools.map { |t| convert_tool(t) }) if tools && !tools.empty?

    if web_search
      web_search_tool = { type: WEB_SEARCH_TOOL_TYPE, name: "web_search" }
      web_search_tool.merge!(web_search) if web_search.is_a?(Hash)
      anthropic_tools << web_search_tool
    end

    if structured_output
      # Strict schema makes optional fields nullable; otherwise Anthropic may
      # return empty strings or whitespace instead of null. The format wins
      # over caller output_config keys because the run loop validates against it.
      params[:output_config] = {
        **(params[:output_config] || {}),
        format: {
          type: "json_schema",
          schema: structured_output.json_schema(strict: true),
        },
      }
    end

    params[:tools] = anthropic_tools unless anthropic_tools.empty?

    params
  end

  private

  #--
  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_prompts = [] #: Array[Hash[Symbol, untyped]]
    conversation_messages = [] #: Array[Hash[Symbol, untyped]]

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_prompts << { type: "text", text: message.content }
      when Riffer::Messages::User
        if message.files.empty?
          conversation_messages << { role: "user", content: message.content }
        else
          content = [{ type: "text", text: message.content }]
          message.files.each { |file| content << convert_file_part(file) }
          conversation_messages << { role: "user", content: content }
        end
      when Riffer::Messages::Assistant
        conversation_messages << convert_assistant(message)
      when Riffer::Messages::Tool
        conversation_messages << {
          role: "user",
          content: [{
            type: "tool_result",
            tool_use_id: message.tool_call_id,
            content: message.content,
          }],
        }
      end
    end

    {
      system: system_prompts.empty? ? nil : system_prompts,
      conversation: conversation_messages,
    }
  end

  #--
  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
  def convert_assistant(message)
    content = message.reasoning.filter_map do |part|
      convert_reasoning_part(part) if part.format == Riffer::Wire::Anthropic::REASONING_FORMAT
    end
    content << { type: "text", text: message.content } if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        type: "tool_use",
        id: tc.call_id,
        name: Riffer::Wire::Anthropic.encode_tool_name(tc.name),
        input: parse_tool_arguments(tc.arguments),
      }
    end

    { role: "assistant", content: content }
  end

  #--
  #: (Riffer::Messages::Assistant::ReasoningPart) -> Hash[Symbol, untyped]
  def convert_reasoning_part(part)
    return { type: "redacted_thinking", data: part.data } if part.type == :encrypted

    { type: "thinking", thinking: part.text.to_s, signature: part.signature }
  end

  #--
  #: (Riffer::Messages::User::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part(file)
    type = file.image? ? "image" : "document"

    source = if file.url?
               { type: "url", url: file.url }
             else
               { type: "base64", media_type: file.media_type, data: file.data }
             end

    { type: type, source: source }
  end

  #--
  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool(tool)
    {
      name: Riffer::Wire::Anthropic.encode_tool_name(tool.name),
      description: tool.description,
      input_schema: tool.parameters_schema(strict: true),
    }
  end

  #--
  #: (String) -> Hash[String, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.empty?

    JSON.parse(arguments)
  end
end
