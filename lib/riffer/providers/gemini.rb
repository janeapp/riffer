# frozen_string_literal: true
# rbs_inline: enabled

require "json"
require "net/http"
require "securerandom"
require "uri"

# Google Gemini provider for Gemini models via the Gemini REST API.
class Riffer::Providers::Gemini < Riffer::Providers::Base
  BASE_URI = URI("https://generativelanguage.googleapis.com") #: URI::Generic

  # Initializes the Gemini provider.
  #
  #--
  #: (?api_key: String?, **untyped) -> void
  def initialize(api_key: nil, **options)
    api_key ||= Riffer.config.gemini.api_key
    @api_key = api_key
  end

  private

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    partitioned = partition_messages(messages)
    tools = options[:tools]
    structured_output = options[:structured_output]

    params = {
      model: model,
      contents: partitioned[:contents]
    }

    params[:systemInstruction] = partitioned[:system_instruction] if partitioned[:system_instruction]

    if tools && !tools.empty?
      params[:tools] = [{
        functionDeclarations: tools.map { |t| convert_tool_to_gemini_format(t) }
      }]
    end

    generation_config = options.except(:tools, :structured_output)

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
    response = post_request(api_path(model, "generateContent"), body)
    handle_api_error!(response) unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body, symbolize_names: true)
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
        arguments: encode_tool_arguments(fc[:args])
      )
    end
  end

  #--
  #: (Hash[Symbol, untyped]) -> Riffer::TokenUsage?
  def extract_token_usage(response)
    usage = response[:usageMetadata]
    return nil unless usage

    Riffer::TokenUsage.new(
      input_tokens: usage[:promptTokenCount] || 0,
      output_tokens: usage[:candidatesTokenCount] || 0
    )
  end

  #--
  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    model = params[:model]
    body = params.except(:model)

    uri = URI("#{BASE_URI}/#{api_path(model, "streamGenerateContent")}&alt=sse")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    full_text = ""
    buffer = +""

    process_chunk = lambda do |chunk|
      buffer << chunk

      while (match = buffer.match(/\r?\n\r?\n/))
        frame = buffer.slice!(0, match.end(0)).strip
        next unless frame.start_with?("data: ")

        json_str = frame.delete_prefix("data: ").strip
        next if json_str.empty?

        parsed = JSON.parse(json_str, symbolize_names: true)
        parts = parsed.dig(:candidates, 0, :content, :parts)

        parts&.each do |part|
          if part[:text]
            full_text += part[:text]
            yielder << Riffer::StreamEvents::TextDelta.new(part[:text])
          elsif part[:functionCall]
            fc = part[:functionCall]
            call_id = "gemini_call_#{SecureRandom.hex(12)}"
            arguments = encode_tool_arguments(fc[:args])
            yielder << Riffer::StreamEvents::ToolCallDone.new(
              item_id: call_id,
              call_id: call_id,
              name: fc[:name],
              arguments: arguments
            )
          end
        end

        usage = parsed[:usageMetadata]
        if usage && usage[:candidatesTokenCount]
          yielder << Riffer::StreamEvents::TokenUsageDone.new(
            token_usage: Riffer::TokenUsage.new(
              input_tokens: usage[:promptTokenCount] || 0,
              output_tokens: usage[:candidatesTokenCount] || 0
            )
          )
        end
      end
    end

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request) do |response|
        handle_api_error!(response) unless response.is_a?(Net::HTTPSuccess)

        begin
          response.read_body { |chunk| process_chunk.call(chunk) }
        rescue IOError
          process_chunk.call(response.body)
        end
      end
    end

    yielder << Riffer::StreamEvents::TextDone.new(full_text) unless full_text.empty?
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> Hash[Symbol, untyped]
  def partition_messages(messages)
    system_parts = []
    contents = []

    messages.each do |message|
      case message
      when Riffer::Messages::System
        system_parts << {text: message.content}
      when Riffer::Messages::User
        if message.files.empty?
          contents << {role: "user", parts: [{text: message.content}]}
        else
          parts = [{text: message.content}]
          message.files.each { |file| parts << convert_file_part_to_gemini_format(file) }
          contents << {role: "user", parts: parts}
        end
      when Riffer::Messages::Assistant
        contents << convert_assistant_to_gemini_format(message)
      when Riffer::Messages::Tool
        contents << {
          role: "user",
          parts: [{
            functionResponse: {
              name: message.name,
              response: {result: message.content}
            }
          }]
        }
      end
    end

    result = {contents: contents}
    result[:system_instruction] = {parts: system_parts} unless system_parts.empty?
    result
  end

  #--
  #: (Riffer::Messages::Assistant) -> Hash[Symbol, untyped]
  def convert_assistant_to_gemini_format(message)
    parts = []
    parts << {text: message.content} if message.content && !message.content.empty?

    message.tool_calls.each do |tc|
      parts << {
        functionCall: {
          name: tc.name,
          args: parse_tool_arguments(tc.arguments)
        }
      }
    end

    {role: "model", parts: parts}
  end

  #--
  #: (Riffer::FilePart) -> Hash[Symbol, untyped]
  def convert_file_part_to_gemini_format(file)
    if file.url?
      raise Riffer::ArgumentError,
        "Gemini provider does not support URL-based file references. Provide base64-encoded data instead."
    end

    {inlineData: {mimeType: file.media_type, data: file.data}}
  end

  #--
  #: (singleton(Riffer::Tool)) -> Hash[Symbol, untyped]
  def convert_tool_to_gemini_format(tool)
    {
      name: tool.name,
      description: tool.description,
      parameters: strip_additional_properties(tool.parameters_schema)
    }
  end

  #--
  #: (untyped) -> String
  def encode_tool_arguments(args)
    return "{}" unless args

    args.is_a?(String) ? args : args.to_json
  end

  #--
  #: (String, Hash[Symbol, untyped]) -> Net::HTTPResponse
  def post_request(path, body)
    uri = URI("#{BASE_URI}/#{path}")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
  end

  #--
  #: (String, String) -> String
  def api_path(model, method)
    "v1beta/models/#{model}:#{method}?key=#{@api_key}"
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

    if schema[:items].is_a?(Hash)
      schema[:items] = strip_additional_properties(schema[:items])
    end

    schema
  end

  #--
  #: (Net::HTTPResponse) -> void
  def handle_api_error!(response)
    body = begin
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError
      {message: response.body}
    end
    error_message = body.dig(:error, :message) || body[:message] || response.body
    raise Riffer::Error, "Gemini API error (#{response.code}): #{error_message}"
  end
end
