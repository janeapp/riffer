# frozen_string_literal: true
# rbs_inline: enabled

require "json"
require "securerandom"

# Google Gemini provider for Gemini models via the Gemini REST API.
class Riffer::Providers::Gemini < Riffer::Providers::Base
  # @rbs @api_key: String?

  VALID_MODEL_PATTERN = /\A[a-zA-Z0-9._-]+\z/ #: Regexp

  FINISH_REASONS = {
    "STOP" => :stop,
    "MAX_TOKENS" => :length,
    "SAFETY" => :content_filter,
    "RECITATION" => :content_filter,
    "BLOCKLIST" => :content_filter,
    "PROHIBITED_CONTENT" => :content_filter,
    "SPII" => :content_filter,
    "IMAGE_SAFETY" => :content_filter,
    "MALFORMED_FUNCTION_CALL" => :error,
  }.freeze #: Hash[String, Symbol]

  # The GenAI semconv well-known provider name.
  #--
  #: () -> String
  def self.semconv_provider_name
    "gcp.gemini"
  end

  #--
  #: (?api_key: String?) -> void
  def initialize(api_key: nil)
    super()
    @api_key = api_key
    @explicit_credentials = !!api_key
  end

  private

  #--
  #: () -> untyped
  def provider_config
    Riffer.config.gemini
  end

  #--
  #: () -> untyped
  def build_default_client
    Riffer::Providers::Gemini::Client.new(api_key: @api_key || Riffer.config.gemini.api_key)
  end

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    partitioned = partition_messages(messages)
    tools = options[:tools]
    structured_output = options[:structured_output]

    params = {
      model: model,
      contents: partitioned[:contents],
    } #: Hash[Symbol, untyped]

    params[:systemInstruction] = partitioned[:system_instruction] if partitioned[:system_instruction]

    if tools && !tools.empty?
      params[:tools] = [{
        functionDeclarations: tools.map { |t| convert_tool_to_gemini_format(t) },
      }]
    end

    # tags propagate to observability only: the Gemini Developer API has no
    # request labels field (unknown body fields are rejected), so :tags is
    # stripped here rather than mapped. Native labels would arrive with a Vertex
    # adapter. See docs/CONFIGURATION.md.
    generation_config = options.except(:tools, :structured_output, :tags)

    if structured_output
      generation_config[:responseMimeType] = "application/json"
      generation_config[:responseSchema] = strip_additional_properties(structured_output.json_schema)
    end

    params[:generationConfig] = generation_config unless generation_config.empty?

    params
  end

  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def execute_generate(params)
    model = params[:model]
    body = params.except(:model)
    client.post(api_path(model, "generateContent"), body)
  end

  #--
  #: (Hash[Symbol, untyped]) -> String
  def extract_content(response)
    parts = response.dig(:candidates, 0, :content, :parts)
    return "" unless parts

    parts.filter_map { |part| part[:text] }.join
  end

  #--
  #: (Hash[Symbol, untyped]) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    parts = response.dig(:candidates, 0, :content, :parts)
    return [] unless parts

    parts.filter_map do |part|
      next unless part[:functionCall]

      fc = part[:functionCall]
      Riffer::Messages::Assistant::ToolCall.new(
        call_id: "gemini_call_#{SecureRandom.hex(12)}",
        name: fc[:name],
        arguments: encode_tool_arguments(fc[:args]),
      )
    end
  end

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    usage = response[:usageMetadata]
    return nil unless usage

    build_token_usage(usage)
  end

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(response)
    parts = response.dig(:candidates, 0, :content, :parts)
    has_function_call = parts&.any? { |part| part[:functionCall] } || false
    build_finish_reason(response.dig(:candidates, 0, :finishReason), tool_calls: has_function_call)
  end

  # Gemini reports STOP even when the candidate carries functionCall parts,
  # so tool-call presence overrides the raw value.
  #--
  #: (String?, tool_calls: bool) -> Riffer::Providers::FinishReason?
  def build_finish_reason(raw_reason, tool_calls:)
    return nil unless raw_reason

    raw = raw_reason.to_s
    reason = FINISH_REASONS.fetch(raw, :other)
    reason = :tool_calls if reason == :stop && tool_calls
    Riffer::Providers::FinishReason.new(reason: reason, raw: raw)
  end

  # Gemini reports thinking tokens outside +candidatesTokenCount+;
  # TokenUsage's output includes them.
  #--
  #: (Hash[Symbol, untyped]) -> Riffer::Providers::TokenUsage
  def build_token_usage(usage)
    apply_pricing(
      Riffer::Providers::TokenUsage.new(
        input_tokens: usage[:promptTokenCount] || 0,
        output_tokens: (usage[:candidatesTokenCount] || 0) + (usage[:thoughtsTokenCount] || 0),
        cache_read_tokens: usage[:cachedContentTokenCount],
      ),
    )
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def execute_stream(params, yielder)
    model = params[:model]
    body = params.except(:model)

    full_text = +""
    buffer = +""
    raw_finish_reason = nil #: String?
    saw_function_call = false

    process_chunk = lambda do |chunk|
      buffer << chunk

      while (match = buffer.match(/\r?\n\r?\n/))
        match_end = match.end(0) #: Integer
        frame = buffer.slice!(0, match_end).to_s.strip
        next unless frame.start_with?("data: ")

        json_str = frame.delete_prefix("data: ").strip
        next if json_str.empty?

        parsed = JSON.parse(json_str, symbolize_names: true)
        parts = parsed.dig(:candidates, 0, :content, :parts)

        parts&.each do |part|
          if part[:text]
            full_text << part[:text]
            yielder << Riffer::StreamEvents::TextDelta.new(part[:text])
          elsif part[:functionCall]
            fc = part[:functionCall]
            saw_function_call = true
            call_id = "gemini_call_#{SecureRandom.hex(12)}"
            arguments = encode_tool_arguments(fc[:args])
            yielder << Riffer::StreamEvents::ToolCallDone.new(
              item_id: call_id,
              call_id: call_id,
              name: fc[:name],
              arguments: arguments,
            )
          end
        end

        raw_finish_reason = parsed.dig(:candidates, 0, :finishReason) || raw_finish_reason

        usage = parsed[:usageMetadata]
        if usage && usage[:candidatesTokenCount]
          yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: build_token_usage(usage))
        end
      end
    end

    path = "#{api_path(model, 'streamGenerateContent')}?alt=sse"
    client.post_stream(path, body) { |chunk| process_chunk.call(chunk) }

    yielder << Riffer::StreamEvents::TextDone.new(full_text) unless full_text.empty?
    yield_finish_reason(yielder, build_finish_reason(raw_finish_reason, tool_calls: saw_function_call))
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_parts = [] #: Array[Hash[Symbol, untyped]]
    contents = [] #: Array[Hash[Symbol, untyped]]

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_parts << { text: message.content }
      when Riffer::Messages::User
        if message.files.empty?
          contents << { role: "user", parts: [{ text: message.content }] }
        else
          parts = [{ text: message.content }]
          message.files.each { |file| parts << convert_file_part_to_gemini_format(file) }
          contents << { role: "user", parts: parts }
        end
      when Riffer::Messages::Assistant
        contents << convert_assistant_to_gemini_format(message)
      when Riffer::Messages::Tool
        contents << {
          role: "user",
          parts: [{
            functionResponse: {
              name: message.name,
              response: { result: message.content },
            },
          }],
        }
      end
    end

    result = { contents: contents } #: Hash[Symbol, untyped]
    result[:system_instruction] = { parts: system_parts } unless system_parts.empty?
    result
  end

  #--
  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
  def convert_assistant_to_gemini_format(message)
    parts = [] #: Array[Hash[Symbol, untyped]]
    parts << { text: message.content } if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      parts << {
        functionCall: {
          name: tc.name,
          args: parse_tool_arguments(tc.arguments),
        },
      }
    end

    { role: "model", parts: parts }
  end

  #--
  #: (Riffer::Messages::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_gemini_format(file)
    if file.url?
      raise Riffer::ArgumentError,
            "Gemini provider does not support URL-based file references. Provide base64-encoded data instead."
    end

    { inlineData: { mimeType: file.media_type, data: file.data } }
  end

  #--
  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool_to_gemini_format(tool)
    {
      name: tool.name,
      description: tool.description,
      parameters: strip_additional_properties(tool.parameters_schema),
    }
  end

  #--
  #: (untyped) -> String
  def encode_tool_arguments(args)
    return "{}" unless args

    args.is_a?(String) ? args : args.to_json
  end

  #--
  #: (String, String) -> String
  def api_path(model, method)
    validate_model!(model)
    "v1beta/models/#{model}:#{method}"
  end

  #--
  #: (String) -> void
  def validate_model!(model)
    return if model.match?(VALID_MODEL_PATTERN)

    raise Riffer::ArgumentError,
          "Invalid model name: #{model.inspect}. Model must contain only alphanumeric characters, " \
          "hyphens, dots, and underscores."
  end

  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def strip_additional_properties(schema)
    schema = schema.dup
    schema.delete(:additionalProperties)

    if schema[:properties]
      schema[:properties] = schema[:properties].transform_values do |prop|
        strip_additional_properties(prop)
      end
    end

    schema[:items] = strip_additional_properties(schema[:items]) if schema[:items].is_a?(Hash)

    schema
  end
end
