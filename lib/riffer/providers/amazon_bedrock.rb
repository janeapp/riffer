# frozen_string_literal: true
# rbs_inline: enabled

require "base64"

# Amazon Bedrock provider for Claude and other foundation models. Requires the
# +aws-sdk-bedrockruntime+ gem.
class Riffer::Providers::AmazonBedrock < Riffer::Providers::Base
  # Matches Anthropic models on Bedrock — bare (+anthropic.claude-...+) and
  # cross-region (+us.anthropic.claude-...+) ids.
  ANTHROPIC_MODEL_PATTERN = /(?:^|\.)anthropic\./ #: Regexp

  FINISH_REASONS = {
    "end_turn" => :stop,
    "stop_sequence" => :stop,
    "max_tokens" => :length,
    "tool_use" => :tool_calls,
    "guardrail_intervened" => :content_filter,
    "content_filtered" => :content_filter,
  }.freeze #: Hash[String, Symbol]

  # Returns the skill adapter for the Bedrock model — XML for Anthropic models
  # (which Bedrock hosts alongside other vendors'), else Markdown.
  #--
  #: (?String?) -> singleton(Riffer::Skills::Adapter)
  def self.skills_adapter(model = nil)
    return Riffer::Skills::XmlAdapter if model && ANTHROPIC_MODEL_PATTERN.match?(model)

    Riffer::Skills::MarkdownAdapter
  end

  # The GenAI semconv well-known provider name.
  #--
  #: () -> String
  def self.semconv_provider_name
    "aws.bedrock"
  end

  #--
  #: () -> void
  def initialize
    super
    depends_on "aws-sdk-bedrockruntime"
  end

  private

  #--
  #: () -> untyped
  def global_client
    Riffer.config.amazon_bedrock.client
  end

  # Compacted so an unset region stays absent: the AWS SDK resolves +AWS_REGION+
  # and the shared config only for a missing argument, and raises
  # +Aws::Errors::MissingRegionError+ on an explicit nil.
  #--
  #: () -> untyped
  def build_client
    api_token = Riffer.config.amazon_bedrock.api_token
    region = Riffer.config.amazon_bedrock.region

    if api_token && !api_token.empty?
      Aws::BedrockRuntime::Client.new(**{
        region: region,
        token_provider: Aws::StaticTokenProvider.new(api_token),
        auth_scheme_preference: ["httpBearerAuth"],
      }.compact)
    else
      Aws::BedrockRuntime::Client.new(**{ region: region }.compact)
    end
  end

  #--
  #: (Riffer::Messages::FilePart) -> Symbol
  def file_delivery(file)
    file.url&.start_with?("s3://") ? :url : :data
  end

  private

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    partitioned_messages = partition_messages(messages)
    tools = options[:tools]
    structured_output = options[:structured_output]
    cache_control = options[:cache_control]
    tags = options[:tags] || {}

    params = {
      model_id: model,
      system: partitioned_messages[:system],
      messages: partitioned_messages[:conversation],
      **options.except(:tools, :structured_output, :cache_control, :tags),
    } #: Hash[Symbol, untyped]

    # requestMetadata is a flat String=>String map used to filter invocation
    # logs; every tag (including the reserved user_id) rides along, since
    # Converse has no dedicated end-user field.
    params[:request_metadata] = tags unless tags.empty?

    if tools && !tools.empty?
      params[:tool_config] = {
        tools: tools.map { |t| convert_tool_to_bedrock_format(t) },
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
              name: "response",
            },
          },
        },
      }
    end

    apply_cache_point(params, cache_control) if cache_control

    params
  end

  # Converse chains +tools -> system -> messages+, so a single +cachePoint+ at
  # the end of the system array (or the tools array, when there is no system
  # prompt) also caches the preceding sections.
  #--
  #: (Hash[Symbol, untyped], untyped) -> void
  def apply_cache_point(params, cache_control)
    cache_point = { cache_point: build_cache_point(cache_control) }
    system = params[:system]
    tools = params.dig(:tool_config, :tools)

    if system && !system.empty?
      system << cache_point
    elsif tools && !tools.empty?
      tools << cache_point
    end
  end

  #--
  #: (untyped) -> Hash[Symbol, untyped]
  def build_cache_point(cache_control)
    point = { type: "default" } #: Hash[Symbol, untyped]
    ttl = cache_control.is_a?(Hash) ? cache_control[:ttl] : nil
    point[:ttl] = ttl if ttl
    point
  end

  #--
  #: (Hash[Symbol, untyped]) -> untyped
  def execute_generate(params)
    client.converse(**params)
  end

  #--
  #: (untyped) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    typed_response = response #: Aws::BedrockRuntime::Client::_ConverseResponseSuccess
    build_token_usage(typed_response.usage)
  end

  # Converse's +input_tokens+ excludes the cache buckets; TokenUsage's
  # input includes them.
  #--
  #: (untyped) -> Riffer::Providers::TokenUsage
  def build_token_usage(usage)
    cache_write = usage.cache_write_input_tokens
    cache_read = usage.cache_read_input_tokens

    apply_pricing(
      Riffer::Providers::TokenUsage.new(
        input_tokens: usage.input_tokens + (cache_write || 0) + (cache_read || 0),
        output_tokens: usage.output_tokens,
        cache_write_tokens: cache_write,
        cache_read_tokens: cache_read,
      ),
    )
  end

  #--
  #: (untyped) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(response)
    typed_response = response #: Aws::BedrockRuntime::Client::_ConverseResponseSuccess
    build_finish_reason(typed_response.stop_reason)
  end

  #--
  #: (untyped) -> Riffer::Providers::FinishReason?
  def build_finish_reason(stop_reason)
    return nil unless stop_reason

    raw = stop_reason.to_s
    Riffer::Providers::FinishReason.new(reason: FINISH_REASONS.fetch(raw, :other), raw: raw)
  end

  #--
  #: (untyped) -> String
  def extract_content(response)
    typed_response = response #: Aws::BedrockRuntime::Client::_ConverseResponseSuccess
    content_blocks = typed_response.output&.message&.content
    return "" if content_blocks.nil? || content_blocks.empty?

    text_content = ""

    content_blocks.each do |block|
      text_content += block.text if block.respond_to?(:text) && block.text
    end

    text_content
  end

  #--
  #: (untyped) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    typed_response = response #: Aws::BedrockRuntime::Client::_ConverseResponseSuccess
    content_blocks = typed_response.output&.message&.content
    return [] if content_blocks.nil? || content_blocks.empty?

    tool_calls = [] #: Array[Riffer::Messages::Assistant::ToolCall]

    content_blocks.each do |block|
      next unless block.respond_to?(:tool_use) && block.tool_use

      tool_calls << Riffer::Messages::Assistant::ToolCall.new(
        call_id: block.tool_use.tool_use_id,
        name: decode_tool_name(block.tool_use.name, tools: @current_tools),
        arguments: block.tool_use.input.to_json,
      )
    end

    tool_calls
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def execute_stream(params, yielder)
    current_state = {
      text: nil,
      tool_call: nil,
    } #: Hash[Symbol, untyped]

    client.converse_stream(**params) do |stream|
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
        when Aws::BedrockRuntime::Types::MessageStopEvent
          yield_finish_reason(yielder, build_finish_reason(event.stop_reason))
        when Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent
          handle_metadata_usage(event, state: current_state, yielder: yielder) if event.usage
        else
          raise_if_stream_exception!(event)
        end
      end
    end
  end

  # Re-raises a Bedrock stream-exception event as the matching
  # +Aws::BedrockRuntime::Errors+ class. ConverseStream delivers API errors on
  # the same channel as content, so without this a mid-stream failure would
  # silently end the stream with no content.
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
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_content_block_start_tool_use(event, state:, yielder:)
    typed_event = event #: Aws::BedrockRuntime::Types::ContentBlockStartEvent
    state[:tool_call] = {
      id: typed_event.start.tool_use.tool_use_id,
      name: decode_tool_name(typed_event.start.tool_use.name, tools: @current_tools),
      arguments: +"",
    }
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_content_block_delta_text_delta(event, state:, yielder:)
    typed_event = event #: Aws::BedrockRuntime::Types::ContentBlockDeltaEvent
    delta_text = typed_event.delta.text
    # Mutating append: += would reallocate and copy the whole accumulated
    # buffer on every delta (O(n^2) per content block). state[:text] is handed
    # off to TextDone and then cleared on block stop, so nothing reads the
    # pre-append string, making in-place mutation safe. Seed with an unfrozen
    # String (+"") so << does not raise under frozen_string_literal.
    state[:text] ||= +""
    state[:text] << delta_text
    yielder << Riffer::StreamEvents::TextDelta.new(delta_text)
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_content_block_delta_tool_use(event, state:, yielder:)
    typed_event = event #: Aws::BedrockRuntime::Types::ContentBlockDeltaEvent
    input_delta = typed_event.delta.tool_use.input

    state[:tool_call][:arguments] << input_delta

    yielder << Riffer::StreamEvents::ToolCallDelta.new(
      item_id: state[:tool_call][:id],
      name: state[:tool_call][:name],
      arguments_delta: input_delta,
    )
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_content_block_stop_text_delta(_event, state:, yielder:)
    yielder << Riffer::StreamEvents::TextDone.new(state[:text])
    state[:text] = nil
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_content_block_stop_tool_use(_event, state:, yielder:)
    tool_call = state[:tool_call]
    yielder << Riffer::StreamEvents::ToolCallDone.new(
      item_id: tool_call[:id],
      call_id: tool_call[:id],
      name: tool_call[:name],
      arguments: tool_call[:arguments],
    )
    state[:tool_call] = nil
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_metadata_usage(event, state:, yielder:)
    typed_event = event #: Aws::BedrockRuntime::Types::ConverseStreamMetadataEvent
    yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: build_token_usage(typed_event.usage))
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_prompts = [] #: Array[Hash[Symbol, untyped]]
    conversation_messages = [] #: Array[Hash[Symbol, untyped]]

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_prompts << { text: message.content }
      when Riffer::Messages::User
        content = [{ text: message.content }]
        message.files.each { |file| content << convert_file_part_to_bedrock_format(file) }
        conversation_messages << { role: "user", content: content }
      when Riffer::Messages::Assistant
        conversation_messages << convert_assistant_to_bedrock_format(message)
      when Riffer::Messages::Tool
        append_tool_result(conversation_messages, message)
      end
    end

    {
      system: system_prompts,
      conversation: conversation_messages,
    }
  end

  #--
  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
  def convert_assistant_to_bedrock_format(message)
    content = [] #: Array[Hash[Symbol, untyped]]
    content << { text: message.content } if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        tool_use: {
          tool_use_id: tc.call_id,
          name: encode_tool_name(tc.name),
          input: parse_tool_arguments(tc.arguments),
        },
      }
    end

    { role: "assistant", content: content }
  end

  #--
  #: (Array[Hash[Symbol, untyped]], Riffer::Messages::Tool) -> void
  def append_tool_result(conversation_messages, message)
    tool_result = {
      tool_result: {
        tool_use_id: message.tool_call_id,
        content: [{ text: message.content }],
      },
    }

    prev = conversation_messages.last
    if prev && prev[:role] == "user" && prev[:content]&.first&.key?(:tool_result)
      prev[:content] << tool_result
    else
      conversation_messages << { role: "user", content: [tool_result] }
    end
  end

  #--
  #: (Riffer::Messages::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_bedrock_format(file)
    format = bedrock_format(file.media_type)

    data = file.data
    source = data ? { bytes: Base64.decode64(data) } : { s3_location: { uri: file.url } }

    if file.image?
      { image: { format: format, source: source } }
    else
      { document: { format: format, name: file.filename, source: source } }
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
    "text/html" => "html",
  }.freeze #: Hash[String, String]
  private_constant :BEDROCK_FORMAT_MAP

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
          json: tool.parameters_schema(strict: true),
        },
      },
    }
  end
end
