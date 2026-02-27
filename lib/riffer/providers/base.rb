# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Base class for all LLM providers in the Riffer framework.
#
# Provides a template-method flow for text generation and streaming.
# Subclasses implement five hook methods; the base class orchestrates them.
#
# ==== Hook methods
#
# - +build_request_params+ — convert messages, tools, and options into SDK params
# - +execute_generate+ — call the SDK and return the raw response
# - +execute_stream+ — call the streaming SDK, mapping events to the yielder
# - +extract_token_usage+ — pull token counts from the SDK response
# - +extract_content+ — extract text content from the SDK response
# - +extract_tool_calls+ — extract tool calls from the SDK response
class Riffer::Providers::Base
  include Riffer::Helpers::Dependencies
  include Riffer::Messages::Converter

  # Generates text using the provider.
  #
  #: (?prompt: String?, ?system: String?, ?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?model: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?, **untyped) -> Riffer::Messages::Assistant
  def generate_text(prompt: nil, system: nil, messages: nil, model: nil, files: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    messages = normalize_messages(prompt: prompt, system: system, messages: messages, files: files)
    validate_normalized_messages!(messages)
    params = build_request_params(messages, model, options)
    response = execute_generate(params)

    content = extract_content(response)
    tool_calls = extract_tool_calls(response)
    token_usage = extract_token_usage(response)
    structured_output = parse_structured_output(content) if options[:structured_output] && tool_calls.empty?

    Riffer::Messages::Assistant.new(
      content,
      tool_calls: tool_calls,
      token_usage: token_usage,
      structured_output: structured_output
    )
  end

  # Streams text from the provider.
  #
  #: (?prompt: String?, ?system: String?, ?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?model: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?, **untyped) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream_text(prompt: nil, system: nil, messages: nil, model: nil, files: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    messages = normalize_messages(prompt: prompt, system: system, messages: messages, files: files)
    validate_normalized_messages!(messages)
    params = build_request_params(messages, model, options)
    Enumerator.new do |yielder|
      execute_stream(params, yielder)
    end
  end

  private

  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    raise NotImplementedError, "Subclasses must implement #build_request_params"
  end

  #: (Hash[Symbol, untyped]) -> untyped
  def execute_generate(params)
    raise NotImplementedError, "Subclasses must implement #execute_generate"
  end

  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    raise NotImplementedError, "Subclasses must implement #execute_stream"
  end

  #: (untyped) -> Riffer::TokenUsage?
  def extract_token_usage(response)
    raise NotImplementedError, "Subclasses must implement #extract_token_usage"
  end

  #: (untyped) -> String
  def extract_content(response)
    raise NotImplementedError, "Subclasses must implement #extract_content"
  end

  #: (untyped) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    raise NotImplementedError, "Subclasses must implement #extract_tool_calls"
  end

  #: (String) -> Hash[Symbol, untyped]?
  def parse_structured_output(content)
    JSON.parse(content, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  #: ((String | Hash[String, untyped])?) -> Hash[String, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?
    arguments.is_a?(String) ? JSON.parse(arguments) : arguments
  end

  #: (prompt: String?, system: String?, messages: Array[Hash[Symbol | String, untyped] | Riffer::Messages::Base]?) -> void
  def validate_input!(prompt:, system:, messages:)
    if messages.nil?
      raise Riffer::ArgumentError, "prompt is required when messages is not provided" if prompt.nil?
    else
      raise Riffer::ArgumentError, "cannot provide both prompt and messages" unless prompt.nil?
      raise Riffer::ArgumentError, "cannot provide both system and messages" unless system.nil?
    end
  end

  #: (prompt: String?, system: String?, messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?files: Array[Hash[Symbol, untyped] | Riffer::FilePart]?) -> Array[Riffer::Messages::Base]
  def normalize_messages(prompt:, system:, messages:, files: nil)
    if messages && files && !files.empty?
      raise Riffer::ArgumentError, "cannot provide both files and messages; attach files to individual messages instead"
    end

    if messages
      return messages.map { |msg| convert_to_message_object(msg) }
    end

    result = []
    result << Riffer::Messages::System.new(system) if system
    file_parts = (files || []).map { |f| convert_to_file_part(f) }
    result << Riffer::Messages::User.new(prompt, files: file_parts)
    result
  end

  #: (Array[Riffer::Messages::Base]) -> void
  def validate_normalized_messages!(messages)
    has_user = messages.any? { |msg| msg.is_a?(Riffer::Messages::User) }
    raise Riffer::ArgumentError, "messages must include at least one user message" unless has_user
  end
end
