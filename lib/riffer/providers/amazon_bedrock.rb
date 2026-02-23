# frozen_string_literal: true
# rbs_inline: enabled

# Amazon Bedrock provider for Claude and other foundation models.
#
# Requires the +aws-sdk-bedrockruntime+ gem to be installed.
#
# See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/BedrockRuntime/Client.html
class Riffer::Providers::AmazonBedrock < Riffer::Providers::Base
  # Initializes the Amazon Bedrock provider.
  #
  #: (?api_token: String?, ?region: String?, **untyped) -> void
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

  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    partitioned_messages = partition_messages(messages)
    tools = options[:tools]
    structured_output = options[:structured_output]

    params = {
      model_id: model,
      system: partitioned_messages[:system],
      messages: partitioned_messages[:conversation],
      **options.except(:tools, :structured_output)
    }

    if tools && !tools.empty?
      params[:tool_config] = {
        tools: tools.map { |t| convert_tool_to_bedrock_format(t) }
      }
    end

    if structured_output
      params[:output_config] = {
        text_format: {
          type: "json_schema",
          structure: {
            json_schema: {
              schema: structured_output.json_schema.to_json,
              name: "response"
            }
          }
        }
      }
    end

    params
  end

  #: (Hash[Symbol, untyped]) -> Aws::BedrockRuntime::Types::ConverseResponse
  def execute_generate(params)
    @client.converse(**params)
  end

  #: (Aws::BedrockRuntime::Types::ConverseResponse) -> Riffer::TokenUsage?
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

  #: (Aws::BedrockRuntime::Types::ConverseResponse, ?Riffer::TokenUsage?) -> Riffer::Messages::Assistant
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

  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    current_state = {
      text: nil,
      tool_call: nil
    }

    @client.converse_stream(**params) do |stream|
      stream.on_event do |event|
        case event.event_type
        when :content_block_start
          handle_content_block_start_tool_use(event, state: current_state, yielder: yielder) if event.start&.tool_use
        when :content_block_delta
          handle_content_block_delta_text_delta(event, state: current_state, yielder: yielder) if event.delta&.text
          handle_content_block_delta_tool_use(event, state: current_state, yielder: yielder) if event.delta&.tool_use
        when :content_block_stop
          handle_content_block_stop_text_delta(event, state: current_state, yielder: yielder) if current_state[:text]
          handle_content_block_stop_tool_use(event, state: current_state, yielder: yielder) if current_state[:tool_call]
        when :metadata
          handle_metadata_usage(event, state: current_state, yielder: yielder) if event.usage
        end
      end
    end
  end

  #: (Aws::BedrockRuntime::Types::ContentBlockStartEvent, state: Hash[Symbol, untyped], yielder: Enumerator[Riffer::StreamEvents::Base, void]) -> void
  def handle_content_block_start_tool_use(event, state:, yielder:)
    state[:tool_call] = {
      id: event.start.tool_use.tool_use_id,
      name: event.start.tool_use.name,
      arguments: ""
    }
  end

  #: (Aws::BedrockRuntime::Types::ContentBlockDeltaEvent, state: Hash[Symbol, untyped], yielder: Enumerator[Riffer::StreamEvents::Base, void]) -> void
  def handle_content_block_delta_text_delta(event, state:, yielder:)
    delta_text = event.delta.text
    state[:text] ||= ""
    state[:text] += delta_text
    yielder << Riffer::StreamEvents::TextDelta.new(delta_text)
  end

  #: (Aws::BedrockRuntime::Types::ContentBlockDeltaEvent, state: Hash[Symbol, untyped], yielder: Enumerator[Riffer::StreamEvents::Base, void]) -> void
  def handle_content_block_delta_tool_use(event, state:, yielder:)
    input_delta = event.delta.tool_use.input

    state[:tool_call][:arguments] += input_delta

    yielder << Riffer::StreamEvents::ToolCallDelta.new(
      item_id: state[:tool_call][:id],
      name: state[:tool_call][:name],
      arguments_delta: input_delta
    )
  end

  #: (Aws::BedrockRuntime::Types::ContentBlockStopEvent, state: Hash[Symbol, untyped], yielder: Enumerator[Riffer::StreamEvents::Base, void]) -> void
  def handle_content_block_stop_text_delta(_event, state:, yielder:)
    yielder << Riffer::StreamEvents::TextDone.new(state[:text])
    state[:text] = nil
  end

  #: (Aws::BedrockRuntime::Types::ContentBlockStopEvent, state: Hash[Symbol, untyped], yielder: Enumerator[Riffer::StreamEvents::Base, void]) -> void
  def handle_content_block_stop_tool_use(_event, state:, yielder:)
    tool_call = state[:tool_call]
    yielder << Riffer::StreamEvents::ToolCallDone.new(
      item_id: tool_call[:id],
      call_id: tool_call[:id],
      name: tool_call[:name],
      arguments: tool_call[:arguments]
    )
    state[:tool_call] = nil
  end

  #: (Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent, state: Hash[Symbol, untyped], yielder: Enumerator[Riffer::StreamEvents::Base, void]) -> void
  def handle_metadata_usage(event, state:, yielder:)
    yielder << Riffer::StreamEvents::TokenUsageDone.new(
      token_usage: Riffer::TokenUsage.new(
        input_tokens: event.usage.input_tokens,
        output_tokens: event.usage.output_tokens,
        cache_creation_tokens: event.usage.cache_write_input_tokens,
        cache_read_tokens: event.usage.cache_read_input_tokens
      )
    )
  end

  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_prompts = []
    conversation_messages = []

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_prompts << {text: message.content}
      when Riffer::Messages::User
        content = [{text: message.content}]
        message.files.each { |file| content << convert_file_part_to_bedrock_format(file) }
        conversation_messages << {role: "user", content: content}
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

  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
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

  #: (Array[Hash[Symbol, untyped]], Riffer::Messages::Tool) -> void
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

  #: (Riffer::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_bedrock_format(file)
    raise Riffer::ArgumentError, "Amazon Bedrock does not support URL file sources; provide base64 data instead" if file.url? && file.data.nil?

    format = bedrock_format(file.media_type)
    bytes = Base64.decode64(file.data)

    if file.image?
      {image: {format: format, source: {bytes: bytes}}}
    else
      {document: {format: format, name: file.filename, source: {bytes: bytes}}}
    end
  end

  BEDROCK_FORMAT_MAP = {
    "image/jpeg" => "jpeg",
    "image/png" => "png",
    "image/gif" => "gif",
    "image/webp" => "webp",
    "application/pdf" => "pdf",
    "text/plain" => "txt",
    "text/csv" => "csv",
    "text/html" => "html"
  }.freeze #: Hash[String, String]

  #: (String) -> String
  def bedrock_format(media_type)
    BEDROCK_FORMAT_MAP.fetch(media_type)
  end

  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
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
