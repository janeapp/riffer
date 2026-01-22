# frozen_string_literal: true

# OpenAI provider for GPT models.
#
# Requires the +openai+ gem to be installed.
class Riffer::Providers::OpenAI < Riffer::Providers::Base
  # Initializes the OpenAI provider.
  #
  # options:: Hash - optional client options
  #
  # Use +:api_key+ to override +Riffer.config.openai.api_key+.
  def initialize(**options)
    depends_on "openai"

    api_key = options.fetch(:api_key, Riffer.config.openai.api_key)
    @client = ::OpenAI::Client.new(api_key: api_key, **options.except(:api_key))
  end

  private

  def perform_generate_text(messages, model:, **options)
    params = build_request_params(messages, model, options)
    response = @client.responses.create(params)

    extract_assistant_message(response.output)
  end

  def perform_stream_text(messages, model:, **options)
    Enumerator.new do |yielder|
      params = build_request_params(messages, model, options)
      stream = @client.responses.stream(params)

      process_stream_events(stream, yielder)
    end
  end

  def build_request_params(messages, model, options)
    reasoning = options[:reasoning]
    tools = options[:tools]

    params = {
      input: convert_messages_to_openai_format(messages),
      model: model,
      reasoning: reasoning && {
        effort: reasoning,
        summary: "auto"
      },
      **options.except(:reasoning, :tools)
    }

    if tools && !tools.empty?
      params[:tools] = tools.map { |t| convert_tool_to_openai_format(t) }
    end

    params.compact
  end

  def convert_messages_to_openai_format(messages)
    messages.flat_map do |message|
      case message
      when Riffer::Messages::System
        {role: "developer", content: message.content}
      when Riffer::Messages::User
        {role: "user", content: message.content}
      when Riffer::Messages::Assistant
        convert_assistant_to_openai_format(message)
      when Riffer::Messages::Tool
        {
          type: "function_call_output",
          call_id: message.tool_call_id,
          output: message.content
        }
      end
    end
  end

  def convert_assistant_to_openai_format(message)
    if message.tool_calls.empty?
      {role: "assistant", content: message.content}
    else
      items = []
      items << {type: "message", role: "assistant", content: message.content} if message.content && !message.content.empty?
      message.tool_calls.each do |tc|
        items << {
          type: "function_call",
          id: tc[:id],
          call_id: tc[:call_id] || tc[:id],
          name: tc[:name],
          arguments: tc[:arguments].is_a?(String) ? tc[:arguments] : tc[:arguments].to_json
        }
      end
      items
    end
  end

  def extract_assistant_message(output_items)
    text_content = ""
    tool_calls = []

    output_items.each do |item|
      case item.type
      when :message
        text_block = item.content&.find { |c| c.type == :output_text }
        text_content = text_block&.text || "" if text_block
      when :function_call
        tool_calls << {
          id: item.id,
          call_id: item.call_id,
          name: item.name,
          arguments: item.arguments
        }
      end
    end

    if text_content.empty? && tool_calls.empty?
      raise Riffer::Error, "No output returned from OpenAI API"
    end

    Riffer::Messages::Assistant.new(text_content, tool_calls: tool_calls)
  end

  def process_stream_events(stream, yielder)
    tool_info = {}

    stream.each do |raw_event|
      track_tool_info(raw_event, tool_info)
      event = convert_event(raw_event, tool_info)

      next unless event

      yielder << event if event
    end
  end

  def track_tool_info(event, tool_info)
    return unless event.type == :"response.output_item.added"
    return unless event.item&.type == :function_call

    tool_info[event.item.id] = {
      name: event.item.name,
      call_id: event.item.call_id
    }
  end

  def convert_event(event, tool_info = {})
    case event.type
    when :"response.output_text.delta"
      Riffer::StreamEvents::TextDelta.new(event.delta)
    when :"response.output_text.done"
      Riffer::StreamEvents::TextDone.new(event.text)
    when :"response.reasoning_summary_text.delta"
      Riffer::StreamEvents::ReasoningDelta.new(event.delta)
    when :"response.reasoning_summary_text.done"
      Riffer::StreamEvents::ReasoningDone.new(event.text)
    when :"response.function_call_arguments.delta"
      tracked = tool_info[event.item_id] || {}
      Riffer::StreamEvents::ToolCallDelta.new(
        item_id: event.item_id,
        name: tracked[:name],
        arguments_delta: event.delta
      )
    when :"response.function_call_arguments.done"
      tracked = tool_info[event.item_id] || {}
      Riffer::StreamEvents::ToolCallDone.new(
        item_id: event.item_id,
        call_id: tracked[:call_id] || event.item_id,
        name: tracked[:name],
        arguments: event.arguments
      )
    end
  end

  def convert_tool_to_openai_format(tool)
    {
      type: "function",
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters_schema,
      strict: true
    }
  end
end
