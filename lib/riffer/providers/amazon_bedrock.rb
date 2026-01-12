# frozen_string_literal: true

class Riffer::Providers::AmazonBedrock < Riffer::Providers::Base
  # Initializes the Amazon Bedrock provider.
  #
  # @param options [Hash] options passed to Aws::BedrockRuntime::Client
  # @option options [String] :api_token Bearer token for API authentication (requires :region)
  # @option options [String] :region AWS region
  # @see https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/BedrockRuntime/Client.html
  def initialize(**options)
    depends_on "aws-sdk-bedrockruntime"

    api_token = options.delete(:api_token) || Riffer.config.amazon_bedrock.api_token

    @client = if api_token && !api_token.empty?
      region = options.delete(:region) || Riffer.config.amazon_bedrock.region || "us-east-1"
      Aws::BedrockRuntime::Client.new(
        region: region,
        token_provider: Aws::StaticTokenProvider.new(api_token),
        auth_scheme_preference: ["httpBearerAuth"]
      )
    else
      Aws::BedrockRuntime::Client.new(**options)
    end
  end

  private

  def perform_generate_text(messages, model:)
    system_prompts, conversation_messages = partition_messages(messages)

    params = {model_id: model, messages: conversation_messages}
    params[:system] = system_prompts unless system_prompts.empty?

    response = @client.converse(**params)
    extract_assistant_message(response)
  end

  def perform_stream_text(messages, model:)
    Enumerator.new do |yielder|
      system_prompts, conversation_messages = partition_messages(messages)

      params = {model_id: model, messages: conversation_messages}
      params[:system] = system_prompts unless system_prompts.empty?

      accumulated_text = ""

      @client.converse_stream(**params) do |stream|
        stream.on_content_block_delta_event do |event|
          if event.delta&.text
            delta_text = event.delta.text
            accumulated_text += delta_text
            yielder << Riffer::StreamEvents::TextDelta.new(delta_text)
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
        conversation_messages << {role: "assistant", content: [{text: message.content}]}
      when Riffer::Messages::Tool
        raise NotImplementedError, "Tool messages are not supported by Amazon Bedrock provider yet"
      end
    end

    [system_prompts, conversation_messages]
  end

  def extract_assistant_message(response)
    output = response.output
    raise Riffer::Error, "No output returned from Bedrock API" if output.nil? || output.message.nil?

    content_blocks = output.message.content
    raise Riffer::Error, "No content returned from Bedrock API" if content_blocks.nil? || content_blocks.empty?

    text_block = content_blocks.find { |block| block.respond_to?(:text) && block.text }
    raise Riffer::Error, "No text content returned from Bedrock API" if text_block.nil?

    Riffer::Messages::Assistant.new(text_block.text)
  end
end
