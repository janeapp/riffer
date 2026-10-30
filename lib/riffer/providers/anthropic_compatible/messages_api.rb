# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::AnthropicCompatible::MessagesAPI < Riffer::Providers::Base
  WEB_SEARCH_TOOL_TYPE = "web_search_20250305" #: String

  FINISH_REASONS = {
    "end_turn" => :stop,
    "stop_sequence" => :stop,
    "max_tokens" => :length,
    "tool_use" => :tool_calls,
    "refusal" => :content_filter,
    "model_context_window_exceeded" => :context_window,
    # A paused server-tool turn resumes only by re-sending the response; the
    # agent loop does not do that, so it has no normalized equivalent.
    "pause_turn" => :other,
  }.freeze #: Hash[String, Symbol]

  # Only parts carrying this tag are replayed, so reasoning captured by another
  # adapter, whose signatures the Messages API may not accept, never reaches the
  # request.
  REASONING_FORMAT = "anthropic-messages-v1" #: String

  # Tags the web search blocks kept among the reasoning parts. Claude signs a
  # thinking block that follows a search over that search, so the blocks go
  # back in their place or the API rejects the turn as modified.
  SERVER_TOOL_FORMAT = "anthropic-messages-server-tool-v1" #: String

  SERVER_TOOL_BLOCK_TYPES = %w[server_tool_use web_search_tool_result].freeze #: Array[String]

  #--
  #: (?String?) -> singleton(Riffer::Skills::Adapter)
  def self.skills_adapter(_model = nil)
    Riffer::Skills::XmlAdapter
  end

  private

  #--
  #: (Symbol) -> Hash[Symbol, untyped]
  def default_reasoning_options(level)
    return { thinking: { type: "disabled" } } if level == :off

    { thinking: { type: "adaptive" }, output_config: { effort: level.to_s } }
  end

  # Relative to the client's base URL.
  #--
  #: (String?, stream: bool) -> String
  def messages_path(_model, stream:)
    "v1/messages"
  end

  #--
  #: (Hash[Symbol, untyped], stream: bool) -> Hash[Symbol, untyped]
  def request_body(params, stream:)
    stream ? params.merge(stream: true) : params
  end

  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def execute_generate(params)
    client.post(messages_path(params[:model], stream: false), request_body(params, stream: false))
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def execute_stream(params, yielder)
    stream = Stream.new(tools: @current_tools)
    decoder = Riffer::Wire::SSE.new

    client.post_stream(messages_path(params[:model], stream: true), request_body(params, stream: true)) do |chunk|
      decoder.feed(chunk) { |data, _event| stream.handle(JSON.parse(data, symbolize_names: true), yielder) }
    end

    message = stream.finish!
    yield_finish_reason(yielder, extract_finish_reason(message))
    usage = extract_token_usage(message)
    yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: usage) if usage
  end

  #--
  #: (Hash[Symbol, untyped]) -> String
  def extract_content(response)
    content_blocks(response).filter_map { |block| block[:text] if block[:type] == "text" }.join
  end

  #--
  #: (Hash[Symbol, untyped]) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    content_blocks(response).filter_map do |block|
      next unless block[:type] == "tool_use"

      Riffer::Messages::Assistant::ToolCall.new(
        call_id: block[:id],
        name: decode_tool_name(block[:name], tools: @current_tools),
        arguments: (block[:input] || {}).to_json,
      )
    end
  end

  #--
  #: (Hash[Symbol, untyped]) -> Array[Riffer::Messages::Assistant::ReasoningPart]
  def extract_reasoning(response)
    content_blocks(response).filter_map { |block| Stream.reasoning_part(block) }
  end

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    usage = response[:usage]
    return nil unless usage

    cache_write = usage[:cache_creation_input_tokens]
    cache_read = usage[:cache_read_input_tokens]

    apply_pricing(
      Riffer::Providers::TokenUsage.new(
        # Anthropic's input_tokens excludes the cache buckets; TokenUsage's includes them.
        input_tokens: (usage[:input_tokens] || 0) + (cache_write || 0) + (cache_read || 0),
        output_tokens: usage[:output_tokens] || 0,
        cache_write_tokens: cache_write,
        cache_read_tokens: cache_read,
      ),
    )
  end

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(response)
    raw = response[:stop_reason]
    return nil unless raw

    Riffer::Providers::FinishReason.new(reason: FINISH_REASONS.fetch(raw, :other), raw: raw)
  end

  #--
  #: (Hash[Symbol, untyped]) -> Array[Hash[Symbol, untyped]]
  def content_blocks(response)
    response[:content] || []
  end

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    partitioned_messages = partition_messages(messages)
    tools = options[:tools]
    structured_output = options[:structured_output]
    web_search = options[:web_search]
    tags = options[:tags] || {}

    max_tokens = options.fetch(:max_tokens, 4096)

    params = {
      model: model,
      messages: partitioned_messages[:conversation],
      max_tokens: max_tokens,
      **options.except(:tools, :max_tokens, :structured_output, :web_search, :tags),
    } #: Hash[Symbol, untyped]

    params[:system] = partitioned_messages[:system] if partitioned_messages[:system]

    metadata = request_metadata(tags)
    params[:metadata] = metadata if metadata

    api_tools = [] #: Array[Hash[Symbol, untyped]]
    api_tools.concat(tools.map { |t| convert_tool(t) }) if tools && !tools.empty?
    api_tools << web_search_tool(web_search) if web_search

    if structured_output
      # The format wins over caller output_config keys because the run loop
      # validates against it.
      params[:output_config] = { **(params[:output_config] || {}), **structured_output_config(structured_output) }
    end

    params[:tools] = api_tools unless api_tools.empty?

    params
  end

  #--
  #: (Hash[String, untyped]) -> Hash[Symbol, untyped]?
  def request_metadata(tags)
    # The Messages API's only request-metadata field is metadata.user_id (opaque, no
    # PII); all other tags survive only on spans.
    user_id = tags["user_id"]
    { user_id: user_id } if user_id
  end

  #--
  #: (untyped) -> Hash[Symbol, untyped]
  def web_search_tool(web_search)
    tool = { type: WEB_SEARCH_TOOL_TYPE, name: "web_search" } #: Hash[Symbol, untyped]
    tool.merge!(web_search) if web_search.is_a?(Hash)
    tool
  end

  #--
  #: (Riffer::Agent::StructuredOutput) -> Hash[Symbol, untyped]
  def structured_output_config(structured_output)
    # Strict schema makes optional fields nullable; otherwise Anthropic may
    # return empty strings or whitespace instead of null.
    {
      format: {
        type: "json_schema",
        schema: structured_output.json_schema(strict: true),
      },
    }
  end

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
      convert_reasoning_part(part) if [REASONING_FORMAT, SERVER_TOOL_FORMAT].include?(part.format)
    end
    content << { type: "text", text: message.content } if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      content << {
        type: "tool_use",
        id: tc.call_id,
        name: encode_tool_name(tc.name),
        input: parse_tool_arguments(tc.arguments),
      }
    end

    { role: "assistant", content: content }
  end

  #--
  #: (Riffer::Messages::Assistant::ReasoningPart) -> Hash[Symbol, untyped]
  def convert_reasoning_part(part)
    return JSON.parse(part.data.to_s, symbolize_names: true) if part.format == SERVER_TOOL_FORMAT
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
      name: encode_tool_name(tool.name),
      description: tool.description,
      input_schema: tool.parameters_schema(strict: true),
    }
  end
end
