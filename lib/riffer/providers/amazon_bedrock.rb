# frozen_string_literal: true
# rbs_inline: enabled

require "base64"

# Amazon Bedrock provider for Claude and other foundation models.
#
# Requires the +aws-sdk-bedrockruntime+ gem to be installed.
#
# See https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/BedrockRuntime/Client.html
class Riffer::Providers::AmazonBedrock < Riffer::Providers::Base
  # Matches Anthropic models on Bedrock: bare ids like
  # +anthropic.claude-3-5-sonnet-20241022-v2:0+ and cross-region prefixed
  # ids like +us.anthropic.claude-sonnet-4-6+.
  ANTHROPIC_MODEL_PATTERN = /(?:^|\.)anthropic\./ #: Regexp

  # Returns the preferred skill adapter for the given Bedrock model.
  #
  # Bedrock hosts models from multiple vendors. Anthropic models prefer
  # XML-rendered catalogs; everything else falls back to the default
  # Markdown adapter.
  #
  #--
  #: (?String?) -> singleton(Riffer::Skills::Adapter)
  def self.skills_adapter(model = nil)
    return Riffer::Skills::XmlAdapter if model && ANTHROPIC_MODEL_PATTERN.match?(model)
    Riffer::Skills::MarkdownAdapter
  end

  # Initializes the Amazon Bedrock provider.
  #
  #--
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

  #--
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
    } #: Hash[Symbol, untyped]

    if tools && !tools.empty?
      params[:tool_config] = {
        tools: tools.map { |t| convert_tool_to_bedrock_format(t) }
      }
    end

    if structured_output
      # Use strict schema to make optional fields nullable. Without this,
      # Bedrock may return string literals like ": null," instead of actual
      # null values for optional fields that the model has no value for.
      params[:output_config] = {
        text_format: {
          type: "json_schema",
          structure: {
            json_schema: {
              schema: structured_output.json_schema(strict: true).to_json,
              name: "response"
            }
          }
        }
      }
    end

    params
  end

  #--
  #: (Hash[Symbol, untyped]) -> Aws::BedrockRuntime::Client::_ConverseResponseSuccess
  def execute_generate(params)
    @client.converse(**params)
  end

  #--
  #: (Aws::BedrockRuntime::Client::_ConverseResponseSuccess) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    usage = response.usage

    Riffer::Providers::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens,
      cache_creation_tokens: usage.cache_write_input_tokens,
      cache_read_tokens: usage.cache_read_input_tokens
    )
  end

  #--
  #: (Aws::BedrockRuntime::Client::_ConverseResponseSuccess) -> String
  def extract_content(response)
    content_blocks = response.output&.message&.content
    return "" if content_blocks.nil? || content_blocks.empty?

    text_content = ""

    content_blocks.each do |block|
      text_content += block.text if block.respond_to?(:text) && block.text
    end

    text_content
  end

  #--
  #: (Aws::BedrockRuntime::Client::_ConverseResponseSuccess) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    content_blocks = response.output&.message&.content
    return [] if content_blocks.nil? || content_blocks.empty?

    tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]

    content_blocks.each do |block|
      if block.respond_to?(:tool_use) && block.tool_use
        tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          call_id: block.tool_use.tool_use_id,
          name: decode_tool_name(block.tool_use.name, tools: @current_tools),
          arguments: block.tool_use.input.to_json
        )
      end
    end

    tool_calls
  end

  #--
  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    current_state = {
      text: nil,
      tool_call: nil
    } #: Hash[Symbol, untyped]

    @client.converse_stream(**params) do |stream|
      stream.on_event do |event|
        case event
        when Aws::BedrockRuntime::Types::ContentBlockStartEvent
          handle_content_block_start_tool_use(event, state: current_state, yielder: yielder) if event.start&.tool_use
        when Aws::BedrockRuntime::Types::ContentBlockDeltaEvent
          handle_content_block_delta_text_delta(event, state: current_state, yielder: yielder) if event.delta&.text
          handle_content_block_delta_tool_use(event, state: current_state, yielder: yielder) if event.delta&.tool_use
        when Aws::BedrockRuntime::Types::ContentBlockStopEvent
          handle_content_block_stop_text_delta(event, state: current_state, yielder: yielder) if current_state[:text]
          handle_content_block_stop_tool_use(event, state: current_state, yielder: yielder) if current_state[:tool_call]
        when Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent
          handle_metadata_usage(event, state: current_state, yielder: yielder) if event.usage
        else
          raise_if_stream_exception!(event)
        end
      end
    end
  end

  # Re-raises a Bedrock stream exception event as the matching
  # +Aws::BedrockRuntime::Errors+ service error. ConverseStream delivers API
  # errors on the same channel as content, so without this a mid-stream
  # failure would silently end the enumerator with no tokens or content.
  #
  # Detection is by class-name suffix: every Bedrock stream-exception struct
  # is named +*Exception+ and has a matching +Aws::BedrockRuntime::Errors+
  # class of the same name (generated via +DynamicErrors+ if not explicit).
  # Non-exception events (e.g. +MessageStartEvent+) pass through silently.
  #--
  #: (untyped) -> void
  def raise_if_stream_exception!(event)
    klass_name = event.class.name&.split("::")&.last
    return unless klass_name&.end_with?("Exception")

    error_klass = Aws::BedrockRuntime::Errors.const_get(klass_name)
    context = Seahorse::Client::RequestContext.new(operation_name: :converse_stream)
    raise error_klass.new(context, event.message, event)
  end

  #--
  #: (Aws::BedrockRuntime::Types::ContentBlockStartEvent, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_start_tool_use(event, state:, yielder:)
    state[:tool_call] = {
      id: event.start.tool_use.tool_use_id,
      name: decode_tool_name(event.start.tool_use.name, tools: @current_tools),
      arguments: ""
    }
  end

  #--
  #: (Aws::BedrockRuntime::Types::ContentBlockDeltaEvent, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_delta_text_delta(event, state:, yielder:)
    delta_text = event.delta.text
    state[:text] ||= ""
    state[:text] += delta_text
    yielder << Riffer::StreamEvents::TextDelta.new(delta_text)
  end

  #--
  #: (Aws::BedrockRuntime::Types::ContentBlockDeltaEvent, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_delta_tool_use(event, state:, yielder:)
    input_delta = event.delta.tool_use.input

    state[:tool_call][:arguments] += input_delta

    yielder << Riffer::StreamEvents::ToolCallDelta.new(
      item_id: state[:tool_call][:id],
      name: state[:tool_call][:name],
      arguments_delta: input_delta
    )
  end

  #--
  #: (Aws::BedrockRuntime::Types::ContentBlockStopEvent, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_content_block_stop_text_delta(_event, state:, yielder:)
    yielder << Riffer::StreamEvents::TextDone.new(state[:text])
    state[:text] = nil
  end

  #--
  #: (Aws::BedrockRuntime::Types::ContentBlockStopEvent, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
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

  #--
  #: (Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
  def handle_metadata_usage(event, state:, yielder:)
    yielder << Riffer::StreamEvents::TokenUsageDone.new(
      token_usage: Riffer::Providers::TokenUsage.new(
        input_tokens: event.usage.input_tokens,
        output_tokens: event.usage.output_tokens,
        cache_creation_tokens: event.usage.cache_write_input_tokens,
        cache_read_tokens: event.usage.cache_read_input_tokens
      )
    )
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_prompts = [] #: Array[Hash[Symbol, untyped]]
    conversation_messages = [] #: Array[Hash[Symbol, untyped]]

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

  #--
  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
  def convert_assistant_to_bedrock_format(message)
    content = [] #: Array[Hash[Symbol, untyped]]
    content << {text: message.content} if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        tool_use: {
          tool_use_id: tc.call_id,
          name: encode_tool_name(tc.name),
          input: parse_tool_arguments(tc.arguments)
        }
      }
    end

    {role: "assistant", content: content}
  end

  #--
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

  #--
  #: (Riffer::Messages::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_bedrock_format(file)
    format = bedrock_format(file.media_type)

    source = if file.data
      {bytes: Base64.decode64(file.data)}
    elsif file.url&.start_with?("s3://")
      {s3_location: {uri: file.url}}
    else
      raise Riffer::ArgumentError, "Amazon Bedrock only supports S3 URI or base64 data file sources"
    end

    if file.image?
      {image: {format: format, source: source}}
    else
      {document: {format: format, name: file.filename, source: source}}
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

  #--
  #: (String) -> String
  def bedrock_format(media_type)
    BEDROCK_FORMAT_MAP.fetch(media_type)
  end

  #--
  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool_to_bedrock_format(tool)
    {
      tool_spec: {
        name: encode_tool_name(tool.name),
        description: tool.description,
        input_schema: {
          json: tool.parameters_schema(strict: true)
        }
      }
    }
  end
end
