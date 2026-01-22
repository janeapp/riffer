# frozen_string_literal: true

require "json"

# Amazon Bedrock provider for Claude and other foundation models.
#
# Requires the +aws-sdk-bedrockruntime+ gem to be installed.
#
# See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/BedrockRuntime/Client.html
class Riffer::Providers::AmazonBedrock < Riffer::Providers::Base
  # Initializes the Amazon Bedrock provider.
  #
  # api_token:: String or nil - Bearer token for API authentication
  # region:: String or nil - AWS region
  # options:: Hash - additional options passed to Aws::BedrockRuntime::Client
  def initialize(api_token: nil, region: nil, **options)
    depends_on "aws-sdk-bedrockruntime"

    api_token ||= Riffer.config.amazon_bedrock.api_token
    region ||= Riffer.config.amazon_bedrock.region

    @client = if api_token && !api_token.empty?
      Aws::BedrockRuntime::Client.new(
        region: region,
        token_provider: Aws::StaticTokenProvider.new(api_token),
        auth_scheme_preference: ["httpBearerAuth"],
        **options
      )
    else
      Aws::BedrockRuntime::Client.new(region: region, **options)
    end
  end

  private

  def perform_generate_text(messages, model:, **options)
    partitioned_messages = partition_messages(messages)
    tools = options[:tools]

    params = {
      model_id: model,
      system: partitioned_messages[:system],
      messages: partitioned_messages[:conversation],
      **options.except(:tools)
    }

    if tools && !tools.empty?
      params[:tool_config] = {
        tools: tools.map { |t| convert_tool_to_bedrock_format(t) }
      }
    end

    response = @client.converse(**params)
    extract_assistant_message(response)
  end

  def perform_stream_text(messages, model:, **options)
    Enumerator.new do |yielder|
      partitioned_messages = partition_messages(messages)
      tools = options[:tools]

      params = {
        model_id: model,
        system: partitioned_messages[:system],
        messages: partitioned_messages[:conversation],
        **options.except(:tools)
      }

      if tools && !tools.empty?
        params[:tool_config] = {
          tools: tools.map { |t| convert_tool_to_bedrock_format(t) }
        }
      end

      accumulated_text = ""
      current_tool_use = nil

      @client.converse_stream(**params) do |stream|
        stream.on_content_block_start_event do |event|
          if event.start&.tool_use
            tool_use = event.start.tool_use
            current_tool_use = {
              id: tool_use.tool_use_id,
              name: tool_use.name,
              arguments: ""
            }
          end
        end

        stream.on_content_block_delta_event do |event|
          if event.delta&.text
            delta_text = event.delta.text
            accumulated_text += delta_text
            yielder << Riffer::StreamEvents::TextDelta.new(delta_text)
          elsif event.delta&.tool_use
            input_delta = event.delta.tool_use.input
            if current_tool_use && input_delta
              current_tool_use[:arguments] += input_delta
              yielder << Riffer::StreamEvents::ToolCallDelta.new(
                item_id: current_tool_use[:id],
                name: current_tool_use[:name],
                arguments_delta: input_delta
              )
            end
          end
        end

        stream.on_content_block_stop_event do |_event|
          if current_tool_use
            yielder << Riffer::StreamEvents::ToolCallDone.new(
              item_id: current_tool_use[:id],
              call_id: current_tool_use[:id],
              name: current_tool_use[:name],
              arguments: current_tool_use[:arguments]
            )
            current_tool_use = nil
          end
        end

        stream.on_message_stop_event do |_event|
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
        system_prompts << {text: message.content}
      when Riffer::Messages::User
        conversation_messages << {role: "user", content: [{text: message.content}]}
      when Riffer::Messages::Assistant
        conversation_messages << convert_assistant_to_bedrock_format(message)
      when Riffer::Messages::Tool
        conversation_messages << {
          role: "user",
          content: [{
            tool_result: {
              tool_use_id: message.tool_call_id,
              content: [{text: message.content}]
            }
          }]
        }
      end
    end

    {
      system: system_prompts,
      conversation: conversation_messages
    }
  end

  def convert_assistant_to_bedrock_format(message)
    content = []
    content << {text: message.content} if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        tool_use: {
          tool_use_id: tc[:id] || tc[:call_id],
          name: tc[:name],
          input: parse_tool_arguments(tc[:arguments])
        }
      }
    end

    {role: "assistant", content: content}
  end

  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?
    arguments.is_a?(String) ? JSON.parse(arguments) : arguments
  end

  def extract_assistant_message(response)
    output = response.output
    raise Riffer::Error, "No output returned from Bedrock API" if output.nil? || output.message.nil?

    content_blocks = output.message.content
    raise Riffer::Error, "No content returned from Bedrock API" if content_blocks.nil? || content_blocks.empty?

    text_content = ""
    tool_calls = []

    content_blocks.each do |block|
      if block.respond_to?(:text) && block.text
        text_content = block.text
      elsif block.respond_to?(:tool_use) && block.tool_use
        tool_calls << {
          id: block.tool_use.tool_use_id,
          call_id: block.tool_use.tool_use_id,
          name: block.tool_use.name,
          arguments: block.tool_use.input.to_json
        }
      end
    end

    if text_content.empty? && tool_calls.empty?
      raise Riffer::Error, "No content returned from Bedrock API"
    end

    Riffer::Messages::Assistant.new(text_content, tool_calls: tool_calls)
  end

  def convert_tool_to_bedrock_format(tool)
    {
      tool_spec: {
        name: tool.name,
        description: tool.description,
        input_schema: {
          json: tool.parameters_schema
        }
      }
    }
  end
end
