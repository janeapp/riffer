# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Providers::OpenRouter < Riffer::Providers::Base
  BASE_URL = "https://openrouter.ai/api/v1" #: String

  FINISH_REASONS = {
    "stop" => :stop,
    "length" => :length,
    "tool_calls" => :tool_calls,
    "function_call" => :tool_calls,
    "content_filter" => :content_filter,
    "error" => :error,
  }.freeze #: Hash[String, Symbol]

  REASONING_TYPES = {
    "reasoning.text" => :text,
    "reasoning.summary" => :summary,
    "reasoning.encrypted" => :encrypted,
  }.freeze #: Hash[String, Symbol]

  # The +reasoning_details+ formats OpenRouter documents. Only parts tagged with
  # one of them are replayed, so parts from other adapters, or with no format,
  # never reach the request.
  REASONING_FORMATS = %w[
    unknown
    openai-responses-v1
    azure-openai-responses-v1
    bedrock-openai-responses-v1
    bedrock-xai-responses-v1
    xai-responses-v1
    meta-responses-v1
    anthropic-claude-v1
    google-gemini-v1
  ].freeze #: Array[String]

  #--
  #: () -> String
  def self.semconv_provider_name
    "openrouter"
  end

  #--
  #: (?client: untyped) -> void
  def initialize(client: nil)
    super
    depends_on "openai"
  end

  #--
  #: (Riffer::Messages::User::FilePart) -> Symbol
  def file_delivery(file)
    file.image? ? :url : :base64
  end

  private

  #--
  #: () -> untyped
  def global_client
    Riffer.config.openrouter.client
  end

  #--
  #: () -> untyped
  def build_client
    api_key = Riffer.config.openrouter.api_key || ENV.fetch("OPENROUTER_API_KEY", nil)
    # Pass a nil api_key rather than omitting it: an omitted key lets the SDK
    # fall back to OPENAI_API_KEY and send an OpenAI credential to OpenRouter.
    ::OpenAI::Client.new(api_key: api_key, base_url: BASE_URL)
  end

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    reasoning = options[:reasoning]
    tools = options[:tools]
    structured_output = options[:structured_output]
    tags = options[:tags] || {}

    params = {
      model: model,
      messages: convert_messages_to_chat_completions_format(messages),
      **options.except(:reasoning, :tools, :structured_output, :tags),
    } #: Hash[Symbol, untyped]

    unless tags.empty?
      params[:metadata] = (params[:metadata] || {}).merge(tags)
      # OpenRouter exposes the legacy Chat Completions user field rather than
      # safety_identifier; the reserved user_id maps there and stays in metadata.
      user = tags["user_id"]
      params[:user] = user if user
    end

    if reasoning
      params[:reasoning] = reasoning.is_a?(String) ? { effort: reasoning } : reasoning
    end

    params[:tools] = tools.map { |t| convert_tool_to_chat_completions_format(t) } if tools && !tools.empty?

    if structured_output
      params[:response_format] = {
        type: "json_schema",
        json_schema: {
          name: "response",
          schema: structured_output.json_schema(strict: true),
          strict: true,
        },
      }
    end

    params.compact
  end

  #--
  #: (Hash[Symbol, untyped]) -> untyped
  def execute_generate(params)
    client.chat.completions.create(**params)
  end

  #--
  #: (untyped) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    typed_response = response #: OpenAI::Models::Chat::ChatCompletion
    usage = typed_response.usage
    return nil unless usage

    build_token_usage(usage)
  end

  #--
  #: (untyped) -> Riffer::Providers::TokenUsage
  def build_token_usage(usage)
    apply_pricing(
      Riffer::Providers::TokenUsage.new(
        input_tokens: usage.prompt_tokens,
        output_tokens: usage.completion_tokens,
        cache_read_tokens: usage.prompt_tokens_details&.cached_tokens,
      ),
    )
  end

  #--
  #: (untyped) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(response)
    typed_response = response #: OpenAI::Models::Chat::ChatCompletion
    choice = typed_response.choices.first
    build_finish_reason(choice&.finish_reason, native: native_finish_reason(choice))
  end

  #--
  #: (untyped, ?native: untyped) -> Riffer::Providers::FinishReason?
  def build_finish_reason(finish_reason, native: nil)
    return nil unless finish_reason

    normalized = finish_reason.to_s
    return nil if normalized.empty?

    # OpenRouter reports the upstream model's own finish reason alongside its
    # normalized one.
    raw = native.to_s.empty? ? normalized : native.to_s
    Riffer::Providers::FinishReason.new(reason: FINISH_REASONS.fetch(normalized, :other), raw: raw)
  end

  #--
  #: (untyped) -> untyped
  def native_finish_reason(choice)
    # Outside the OpenAI schema, so only reachable through the SDK model's raw
    # data hash.
    choice && choice.to_h[:native_finish_reason]
  end

  #--
  #: (untyped) -> String
  def extract_content(response)
    typed_response = response #: OpenAI::Models::Chat::ChatCompletion
    typed_response.choices.first&.message&.content || ""
  end

  #--
  #: (untyped) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    typed_response = response #: OpenAI::Models::Chat::ChatCompletion
    message = typed_response.choices.first&.message
    return [] unless message

    tool_calls = message.tool_calls
    return [] if tool_calls.nil? || tool_calls.empty?

    tool_calls.filter_map do |tc|
      next unless tc.is_a?(::OpenAI::Models::Chat::ChatCompletionMessageFunctionToolCall)

      Riffer::Messages::Assistant::ToolCall.new(
        call_id: tc.id,
        name: decode_tool_name(tc.function.name, tools: @current_tools),
        arguments: tc.function.arguments,
      )
    end
  end

  #--
  #: (untyped) -> Array[Riffer::Messages::Assistant::ReasoningPart]
  def extract_reasoning(response)
    typed_response = response #: OpenAI::Models::Chat::ChatCompletion
    message = typed_response.choices.first&.message
    details = message && reasoning_details(message)
    (details || []).filter_map { |detail| build_reasoning_part(detail) }
  end

  # The openai gem's typed models strip fields outside OpenAI's spec, so
  # +reasoning_details+ is only reachable through the model's raw data hash.
  #--
  #: (untyped) -> Array[Hash[Symbol, untyped]]?
  def reasoning_details(model)
    model[:reasoning_details]
  end

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Messages::Assistant::ReasoningPart?
  def build_reasoning_part(detail)
    type = REASONING_TYPES.fetch(detail[:type], nil)
    return nil unless type

    Riffer::Messages::Assistant::ReasoningPart.new(
      type: type,
      text: detail[:text] || detail[:summary],
      data: detail[:data],
      signature: detail[:signature],
      id: detail[:id],
      format: detail[:format],
    )
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def execute_stream(params, yielder)
    # OpenRouter omits usage from streams unless explicitly opted in.
    stream_options = (params[:stream_options] || {}).merge(include_usage: true)
    stream_params = params.merge(stream_options: stream_options)

    state = {
      text: +"",
      reasoning_details: {},
      tool_calls: {},
      finish_reason: nil,
      native_finish_reason: nil,
    } #: Hash[Symbol, untyped]

    # stream_raw, not stream: stream aggregates chunks into higher-level
    # events, but mapping to Riffer::StreamEvents needs the raw deltas.
    stream = client.chat.completions.stream_raw(**stream_params)
    begin
      stream.each do |chunk|
        handle_stream_chunk(chunk, state: state, yielder: yielder)
      end
    ensure
      # The OpenAI SDK does not auto-close the SSE socket on iteration
      # interrupt, so close explicitly. Idempotent and a no-op after EOF.
      stream.close
    end

    # Chat Completions has no per-tool terminal event, so flush any leftover
    # tool calls here in case finish_reason is missing or not "tool_calls".
    emit_tool_call_done_events(state: state, yielder: yielder) unless state[:tool_calls].empty?

    yielder << Riffer::StreamEvents::TextDone.new(state[:text]) unless state[:text].empty?
    state[:reasoning_details].each_value do |detail|
      part = build_reasoning_part(detail)
      yielder << Riffer::StreamEvents::ReasoningDone.new(part) if part
    end
    yield_finish_reason(yielder, build_finish_reason(state[:finish_reason], native: state[:native_finish_reason]))
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_stream_chunk(chunk, state:, yielder:)
    typed_chunk = chunk #: OpenAI::Models::Chat::ChatCompletionChunk
    choice = typed_chunk.choices&.first
    delta = choice&.delta

    if delta
      handle_text_delta(delta, state: state, yielder: yielder)
      handle_reasoning_delta(delta, state: state, yielder: yielder)
      handle_tool_call_deltas(delta, state: state, yielder: yielder)
    end

    state[:finish_reason] = choice.finish_reason if choice&.finish_reason
    state[:native_finish_reason] = native_finish_reason(choice) || state[:native_finish_reason]

    emit_tool_call_done_events(state: state, yielder: yielder) if choice && finish_reason_is_tool_calls?(choice)

    return unless typed_chunk.usage

    yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: build_token_usage(typed_chunk.usage))
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_text_delta(delta, state:, yielder:)
    typed_delta = delta #: OpenAI::Models::Chat::ChatCompletionChunk::Choice::Delta
    content = typed_delta.content
    return if content.nil? || content.empty?

    state[:text] << content
    yielder << Riffer::StreamEvents::TextDelta.new(content)
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_reasoning_delta(delta, state:, yielder:)
    details = reasoning_details(delta)
    return if details.nil?

    details.each do |detail|
      accumulate_reasoning_detail(state[:reasoning_details], detail)
      text = detail[:text] || detail[:summary]
      yielder << Riffer::StreamEvents::ReasoningDelta.new(text) unless text.nil? || text.empty?
    end
  end

  # OpenRouter streams one reasoning block as many fragments sharing an
  # +index+: prose and payload arrive in pieces to concatenate, while the
  # signature, id, and format arrive once, often on the last fragment. Keying
  # on +type+ as well keeps index-less fragments of different kinds apart.
  #--
  #: (Hash[untyped, Hash[Symbol, untyped]], Hash[Symbol, untyped]) -> void
  def accumulate_reasoning_detail(accumulated, detail)
    entry = accumulated[[detail[:index], detail[:type]]] ||= { type: detail[:type] }
    %i[text summary data].each { |key| (entry[key] ||= +"") << detail[key] if detail[key] }
    %i[signature id format].each { |key| entry[key] = detail[key] if detail[key] }
  end

  #--
  #: (untyped, state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def handle_tool_call_deltas(delta, state:, yielder:)
    typed_delta = delta #: OpenAI::Models::Chat::ChatCompletionChunk::Choice::Delta
    tool_calls = typed_delta.tool_calls
    return if tool_calls.nil? || tool_calls.empty?

    tool_calls.each do |tc|
      entry = state[:tool_calls][tc.index] ||= { id: nil, name: nil, arguments: +"" }
      entry[:id] = tc.id if tc.id

      fn = tc.function
      next unless fn

      entry[:name] = decode_tool_name(fn.name, tools: @current_tools) if fn.name

      args_delta = fn.arguments
      next if args_delta.nil? || args_delta.empty?

      entry[:arguments] << args_delta
      yielder << Riffer::StreamEvents::ToolCallDelta.new(
        item_id: entry[:id] || "tool_#{tc.index}",
        name: entry[:name],
        arguments_delta: args_delta,
      )
    end
  end

  #--
  #: (state: Hash[Symbol, untyped], yielder: Riffer::Providers::_EventSink) -> void
  def emit_tool_call_done_events(state:, yielder:)
    state[:tool_calls].each do |index, entry|
      fallback = "tool_#{index}"
      yielder << Riffer::StreamEvents::ToolCallDone.new(
        item_id: entry[:id] || fallback,
        call_id: entry[:id] || fallback,
        name: entry[:name],
        arguments: entry[:arguments],
      )
    end
    state[:tool_calls] = {}
  end

  #--
  #: (untyped) -> bool
  def finish_reason_is_tool_calls?(choice)
    typed_choice = choice #: OpenAI::Models::Chat::ChatCompletionChunk::Choice
    typed_choice.finish_reason.to_s == "tool_calls"
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> Array[Hash[Symbol, untyped]]
  def convert_messages_to_chat_completions_format(messages)
    messages.flat_map do |message|
      case message
      when Riffer::Messages::System
        { role: "system", content: message.content }
      when Riffer::Messages::User
        if message.files.empty?
          { role: "user", content: message.content }
        else
          content = [{ type: "text", text: message.content }]
          message.files.each { |file| content << convert_file_part_to_chat_completions_format(file) }
          { role: "user", content: content }
        end
      when Riffer::Messages::Assistant
        convert_assistant_to_chat_completions_format(message)
      when Riffer::Messages::Tool
        { role: "tool", tool_call_id: message.tool_call_id, content: message.content }
      else
        raise Riffer::ArgumentError, "unsupported message type: #{message.class}"
      end
    end
  end

  #--
  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
  def convert_assistant_to_chat_completions_format(message)
    msg = { role: "assistant" } #: Hash[Symbol, untyped]
    msg[:content] = message.content if message.content && !message.content.empty?

    unless message.tool_calls.empty?
      msg[:tool_calls] = message.tool_calls.map do |tc|
        {
          id: tc.call_id,
          type: "function",
          function: {
            name: encode_tool_name(tc.name),
            arguments: tc.arguments,
          },
        }
      end
    end

    details = message.reasoning.filter_map do |part|
      convert_reasoning_part_to_detail(part) if REASONING_FORMATS.include?(part.format)
    end
    msg[:reasoning_details] = details unless details.empty?

    msg
  end

  #--
  #: (Riffer::Messages::Assistant::ReasoningPart) -> Hash[Symbol, untyped]
  def convert_reasoning_part_to_detail(part)
    {
      type: REASONING_TYPES.key(part.type),
      (part.type == :summary ? :summary : :text) => part.text,
      data: part.data,
      signature: part.signature,
      id: part.id,
      format: part.format,
    }.compact
  end

  #--
  #: (Riffer::Messages::User::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_chat_completions_format(file)
    if file.image?
      image_url = file.url? ? file.url : "data:#{file.media_type};base64,#{file.data}"
      { type: "image_url", image_url: { url: image_url } }
    else
      data_uri = "data:#{file.media_type};base64,#{file.data}"
      block = { type: "file", file: { file_data: data_uri } } #: Hash[Symbol, untyped]
      block[:file][:filename] = file.filename if file.filename
      block
    end
  end

  #--
  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool_to_chat_completions_format(tool)
    {
      type: "function",
      function: {
        name: encode_tool_name(tool.name),
        description: tool.description,
        parameters: tool.parameters_schema(strict: true),
        strict: true,
      },
    }
  end
end
