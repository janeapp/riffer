# frozen_string_literal: true

require "json"

# Anthropic provider for Claude models via the Anthropic API.
#
# Requires the +anthropic+ gem to be installed.
#
# See https://github.com/anthropics/anthropic-sdk-ruby
class Riffer::Providers::Anthropic < Riffer::Providers::Base
  # Initializes the Anthropic provider.
  #
  # api_key:: String or nil - Anthropic API key
  # options:: Hash - additional options passed to Anthropic::Client
  def initialize(api_key: nil, **options)
    depends_on "anthropic"

    api_key ||= Riffer.config.anthropic.api_key

    @client = Anthropic::Client.new(api_key: api_key, **options)
  end

  private

  def perform_generate_text(messages, model:, **options)
    partitioned_messages = partition_messages(messages)
    tools = options[:tools]

    max_tokens = options.fetch(:max_tokens, 4096)

    params = {
      model: model,
      messages: partitioned_messages[:conversation],
      max_tokens: max_tokens,
      **options.except(:tools, :max_tokens)
    }

    params[:system] = partitioned_messages[:system] if partitioned_messages[:system]

    if tools && !tools.empty?
      params[:tools] = tools.map { |t| convert_tool_to_anthropic_format(t) }
    end

    response = @client.messages.create(**params)
    extract_assistant_message(response)
  end

  def perform_stream_text(messages, model:, **options)
    Enumerator.new do |yielder|
      partitioned_messages = partition_messages(messages)
      tools = options[:tools]

      max_tokens = options.fetch(:max_tokens, 4096)

      params = {
        model: model,
        messages: partitioned_messages[:conversation],
        max_tokens: max_tokens,
        **options.except(:tools, :max_tokens)
      }

      params[:system] = partitioned_messages[:system] if partitioned_messages[:system]

      if tools && !tools.empty?
        params[:tools] = tools.map { |t| convert_tool_to_anthropic_format(t) }
      end

      accumulated_text = ""
      accumulated_reasoning = ""
      current_tool_use = nil

      stream = @client.messages.stream(**params)
      stream.each do |event|
        case event
        when Anthropic::Streaming::TextEvent
          accumulated_text += event.text
          yielder << Riffer::StreamEvents::TextDelta.new(event.text)

        when Anthropic::Streaming::ThinkingEvent
          accumulated_reasoning += event.thinking
          yielder << Riffer::StreamEvents::ReasoningDelta.new(event.thinking)

        when Anthropic::Streaming::InputJsonEvent
          # Tool call JSON delta - we need to track the tool use block
          if current_tool_use.nil?
            # Find the current tool use block being built
            current_tool_use = {id: nil, name: nil, arguments: ""}
          end
          current_tool_use[:arguments] += event.partial_json
          yielder << Riffer::StreamEvents::ToolCallDelta.new(
            item_id: current_tool_use[:id] || "pending",
            name: current_tool_use[:name],
            arguments_delta: event.partial_json
          )

        when Anthropic::Streaming::ContentBlockStopEvent
          content_block = event.content_block
          if content_block.respond_to?(:type)
            block_type = content_block.type.to_s
            if block_type == "tool_use"
              # content_block.input is already a JSON string when streaming
              arguments = content_block.input.is_a?(String) ? content_block.input : content_block.input.to_json
              yielder << Riffer::StreamEvents::ToolCallDone.new(
                item_id: content_block.id,
                call_id: content_block.id,
                name: content_block.name,
                arguments: arguments
              )
              current_tool_use = nil
            elsif block_type == "thinking" && !accumulated_reasoning.empty?
              yielder << Riffer::StreamEvents::ReasoningDone.new(accumulated_reasoning)
            end
          end

        when Anthropic::Streaming::MessageStopEvent
          yielder << Riffer::StreamEvents::TextDone.new(accumulated_text)
        end
      end
    end
  end

  def partition_messages(messages)
    system_prompts = []
    conversation_messages = []

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_prompts << {type: "text", text: message.content}
      when Riffer::Messages::User
        conversation_messages << {role: "user", content: message.content}
      when Riffer::Messages::Assistant
        conversation_messages << convert_assistant_to_anthropic_format(message)
      when Riffer::Messages::Tool
        conversation_messages << {
          role: "user",
          content: [{
            type: "tool_result",
            tool_use_id: message.tool_call_id,
            content: message.content
          }]
        }
      end
    end

    {
      system: system_prompts.empty? ? nil : system_prompts,
      conversation: conversation_messages
    }
  end

  def convert_assistant_to_anthropic_format(message)
    content = []
    content << {type: "text", text: message.content} if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        type: "tool_use",
        id: tc[:id] || tc[:call_id],
        name: tc[:name],
        input: parse_tool_arguments(tc[:arguments])
      }
    end

    {role: "assistant", content: content}
  end

  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?
    arguments.is_a?(String) ? JSON.parse(arguments) : arguments
  end

  def extract_assistant_message(response)
    content_blocks = response.content
    raise Riffer::Error, "No content returned from Anthropic API" if content_blocks.nil? || content_blocks.empty?

    text_content = ""
    tool_calls = []

    content_blocks.each do |block|
      block_type = block.type.to_s
      case block_type
      when "text"
        text_content = block.text
      when "tool_use"
        tool_calls << {
          id: block.id,
          call_id: block.id,
          name: block.name,
          arguments: block.input.to_json
        }
      end
    end

    if text_content.empty? && tool_calls.empty?
      raise Riffer::Error, "No content returned from Anthropic API"
    end

    Riffer::Messages::Assistant.new(text_content, tool_calls: tool_calls)
  end

  def convert_tool_to_anthropic_format(tool)
    {
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters_schema
    }
  end
end
