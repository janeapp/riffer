# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Amazon Bedrock provider for Claude and other foundation models.
#
# Requires the +aws-sdk-bedrockruntime+ gem to be installed.
#
# See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/BedrockRuntime/Client.html
class Riffer::Providers::AmazonBedrock < Riffer::Providers::Base
  #: @client: Aws::BedrockRuntime::Client

  # Initializes the Amazon Bedrock provider.
  #
  #: api_token: String? -- Bearer token for API authentication
  #: region: String? -- AWS region
  #: **options: untyped
  #: return: void
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

  #: messages: Array[Riffer::Messages::Base]
  #: model: String
  #: **options: untyped
  #: return: Riffer::Messages::Assistant
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
    extract_assistant_message(response, extract_token_usage(response))
  end

  #: messages: Array[Riffer::Messages::Base]
  #: model: String
  #: **options: untyped
  #: return: Enumerator[Riffer::StreamEvents::Base, void]
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

        stream.on_metadata_event do |event|
          if event.usage
            usage = event.usage
            yielder << Riffer::StreamEvents::TokenUsageDone.new(
              token_usage: Riffer::TokenUsage.new(
                input_tokens: usage.input_tokens,
                output_tokens: usage.output_tokens,
                cache_creation_tokens: usage.cache_write_input_tokens,
                cache_read_tokens: usage.cache_read_input_tokens
              )
            )
          end
        end
      end
    end
  end

  #: messages: Array[Riffer::Messages::Base]
  #: return: Hash[Symbol, untyped]
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
        append_tool_result(conversation_messages, message)
      end
    end

    {
      system: system_prompts,
      conversation: conversation_messages
    }
  end

  #: conversation_messages: Array[Hash[Symbol, untyped]]
  #: message: Riffer::Messages::Tool
  #: return: void
  def append_tool_result(conversation_messages, message)
    tool_result = {
      tool_result: {
        tool_use_id: message.tool_call_id,
        content: [{text: message.content}]
      }
    }

    prev = conversation_messages.last
    if prev && prev[:role] == "user" && prev[:content]&.first&.key?(:tool_result)
      prev[:content] << tool_result
    else
      conversation_messages << {role: "user", content: [tool_result]}
    end
  end

  #: message: Riffer::Messages::Assistant
  #: return: Hash[Symbol, untyped]
  def convert_assistant_to_bedrock_format(message)
    content = []
    content << {text: message.content} if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        tool_use: {
          tool_use_id: tc.id || tc.call_id,
          name: tc.name,
          input: parse_tool_arguments(tc.arguments)
        }
      }
    end

    {role: "assistant", content: content}
  end

  #: arguments: (String | Hash[String, untyped])?
  #: return: Hash[String, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?
    arguments.is_a?(String) ? JSON.parse(arguments) : arguments
  end

  #: response: Aws::BedrockRuntime::Types::ConverseResponse
  #: return: Riffer::TokenUsage?
  def extract_token_usage(response)
    usage = response.usage
    return nil unless usage

    Riffer::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens,
      cache_creation_tokens: usage.cache_write_input_tokens,
      cache_read_tokens: usage.cache_read_input_tokens
    )
  end

  #: response: Aws::BedrockRuntime::Types::ConverseResponse
  #: token_usage: Riffer::TokenUsage?
  #: return: Riffer::Messages::Assistant
  def extract_assistant_message(response, token_usage = nil)
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
        tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          id: block.tool_use.tool_use_id,
          call_id: block.tool_use.tool_use_id,
          name: block.tool_use.name,
          arguments: block.tool_use.input.to_json
        )
      end
    end

    if text_content.empty? && tool_calls.empty?
      raise Riffer::Error, "No content returned from Bedrock API"
    end

    Riffer::Messages::Assistant.new(text_content, tool_calls: tool_calls, token_usage: token_usage)
  end

  #: tool: singleton(Riffer::Tool)
  #: return: Hash[Symbol, untyped]
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
