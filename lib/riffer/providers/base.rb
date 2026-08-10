# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Base class for all LLM providers. A template-method flow: subclasses implement
# the hooks (+build_request_params+, +execute_generate+, +execute_stream+,
# +extract_token_usage+, +extract_content+, +extract_tool_calls+) and the base
# class orchestrates them.
class Riffer::Providers::Base
  # @rbs @current_tools: Array[singleton(Riffer::Tool)]
  # @rbs @current_model: String?

  WIRE_SEPARATOR = "__" #: String

  # Returns the preferred skill adapter for this provider; override in
  # subclasses (optionally introspecting +model+) for provider-specific formats.
  #--
  #: (?String?) -> singleton(Riffer::Skills::Adapter)
  def self.skills_adapter(_model = nil)
    Riffer::Skills::MarkdownAdapter
  end

  # Returns the provider name stamped as <tt>gen_ai.provider.name</tt> on trace
  # spans, ideally a GenAI semconv well-known value. Defaults to the snake_cased
  # class name rather than raising like the abstract provider methods, so
  # enabling tracing never breaks an otherwise-working custom provider.
  #--
  #: () -> String
  def self.semconv_provider_name
    class_name = name
    return "unknown" unless class_name

    Riffer::Helpers::ClassNameConverter.convert(class_name.split("::").last.to_s)
  end

  # Generates text using the provider.
  #
  #--
  #: (?prompt: String?, ?system: String?, ?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?model: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, **untyped) -> Riffer::Messages::Assistant
  def generate_text(prompt: nil, system: nil, messages: nil, model: nil, files: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    @current_tools = options[:tools] || [] #: Array[singleton(Riffer::Tool)]
    @current_model = model
    messages = normalize_messages(prompt: prompt, system: system, messages: messages, files: files)
    validate_normalized_messages!(messages)
    messages = merge_consecutive_messages(messages)
    params = build_request_params(messages, model, options)

    in_chat_span(model, messages, options) do |span|
      response = execute_generate(params)

      content = extract_content(response)
      tool_calls = extract_tool_calls(response)
      token_usage = extract_token_usage(response)
      finish_reason = extract_finish_reason(response)
      structured_output = parse_structured_output(content) if options[:structured_output] && tool_calls.empty?

      Riffer::Tracing.record_usage(span, token_usage)
      record_finish_reason(span, finish_reason&.reason, finish_reason&.raw)
      capture_output(span, content: content, tool_calls: tool_calls, finish_reason: finish_reason&.reason)

      Riffer::Messages::Assistant.new(
        content,
        tool_calls: tool_calls,
        token_usage: token_usage,
        structured_output: structured_output,
        finish_reason: finish_reason&.reason,
      )
    end
  end

  # Streams text from the provider.
  #
  #--
  #: (?prompt: String?, ?system: String?, ?messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?model: String?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?, **untyped) -> Enumerator[Riffer::StreamEvents::Base, void]
  def stream_text(prompt: nil, system: nil, messages: nil, model: nil, files: nil, **options)
    validate_input!(prompt: prompt, system: system, messages: messages)
    @current_tools = options[:tools] || [] #: Array[singleton(Riffer::Tool)]
    @current_model = model
    messages = normalize_messages(prompt: prompt, system: system, messages: messages, files: files)
    validate_normalized_messages!(messages)
    messages = merge_consecutive_messages(messages)
    params = build_request_params(messages, model, options)

    # The enumerator body runs in its own fiber, where the fiber-local OTEL
    # context is empty — capture here so the chat span parents to the caller's
    # trace.
    trace_context = Riffer::Tracing.current_context
    Enumerator.new do |yielder|
      Riffer::Tracing.with_context(trace_context) do
        in_chat_span(model, messages, options) do |span|
          sink = span.recording? ? Riffer::Tracing::StreamRecorder.new(yielder) : yielder
          execute_stream(params, sink)
          record_stream_outcome(span, sink) if sink.is_a?(Riffer::Tracing::StreamRecorder)
        end
      end
    end
  end

  private

  #: (String) -> true
  def depends_on(gem_name)
    Riffer::Helpers::Dependencies.depends_on(gem_name)
  end

  #--
  #: (String) -> String
  def encode_tool_name(name)
    name.gsub("/", WIRE_SEPARATOR)
  end

  #--
  #: (String, tools: Array[singleton(Riffer::Tool)]) -> String
  def decode_tool_name(wire_name, tools:)
    tool = tools.find { |t| encode_tool_name(t.name) == wire_name }
    tool ? tool.name : wire_name
  end

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    raise NotImplementedError, "Subclasses must implement #build_request_params"
  end

  #--
  #: (Hash[Symbol, untyped]) -> untyped
  def execute_generate(params)
    raise NotImplementedError, "Subclasses must implement #execute_generate"
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def execute_stream(params, yielder)
    raise NotImplementedError, "Subclasses must implement #execute_stream"
  end

  #--
  #: (untyped) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    raise NotImplementedError, "Subclasses must implement #extract_token_usage"
  end

  #: (Riffer::Providers::TokenUsage) -> Riffer::Providers::TokenUsage
  def apply_pricing(usage)
    rates = pricing_rates
    return usage unless rates

    cost = rates.cost_for(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens,
      cache_read_tokens: usage.cache_read_tokens,
      cache_write_tokens: usage.cache_write_tokens,
    )
    Riffer::Providers::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens,
      cache_write_tokens: usage.cache_write_tokens,
      cache_read_tokens: usage.cache_read_tokens,
      cost: cost,
    )
  end

  #--
  #: () -> Riffer::Config::Pricing::Rates?
  def pricing_rates
    model = @current_model
    return nil unless model

    pricing = Riffer.config.pricing
    return nil if pricing.empty?

    key = Riffer::Providers::Repository.key_for(self.class)
    return nil unless key

    pricing.rates_for("#{key}/#{model}")
  end

  # Defaults to nil rather than raising — finish reasons are optional, so
  # providers that don't report one stay valid.
  #--
  #: (untyped) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(_response)
    nil
  end

  #--
  #: (untyped) -> String
  def extract_content(response)
    raise NotImplementedError, "Subclasses must implement #extract_content"
  end

  #--
  #: (untyped) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    raise NotImplementedError, "Subclasses must implement #extract_tool_calls"
  end

  # A deliberate whitelist — caller options outside it stay off spans.
  REQUEST_PARAM_ATTRIBUTES = {
    temperature: "gen_ai.request.temperature",
    max_tokens: "gen_ai.request.max_tokens",
    max_output_tokens: "gen_ai.request.max_tokens",
    top_p: "gen_ai.request.top_p",
    top_k: "gen_ai.request.top_k",
    frequency_penalty: "gen_ai.request.frequency_penalty",
    presence_penalty: "gen_ai.request.presence_penalty",
    seed: "gen_ai.request.seed",
    stop_sequences: "gen_ai.request.stop_sequences",
  }.freeze #: Hash[Symbol, String]

  #--
  #: [R] (String?, Array[Riffer::Messages::Base], Hash[Symbol, untyped]) { (Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span) -> R } -> R
  def in_chat_span(model, messages, options)
    Riffer::Tracing.in_span(model ? "chat #{model}" : "chat", attributes: chat_span_attributes(model, options),
                                                              kind: :client,) do |span|
      capture_input(span, messages)
      yield span
    rescue StandardError => e
      # The backend records the exception and error status on the re-raise;
      # error.type is the one semconv attribute it doesn't set.
      span.set_attribute("error.type", e.class.name)
      raise
    end
  end

  #--
  #: (String?, Hash[Symbol, untyped]) -> Hash[String, untyped]
  def chat_span_attributes(model, options)
    attributes = {
      "gen_ai.operation.name" => "chat",
      "gen_ai.provider.name" => self.class.semconv_provider_name,
    } #: Hash[String, untyped]
    attributes["gen_ai.request.model"] = model if model

    REQUEST_PARAM_ATTRIBUTES.each do |key, attribute|
      value = options[key]
      attributes[attribute] = value if value
    end

    attributes.merge(tag_attributes(options[:tags] || {}))
  end

  # Maps normalized tags to their namespaced span attribute form. An empty map
  # yields an empty hash, so merging it is a no-op.
  #--
  #: (Hash[String, String]) -> Hash[String, String]
  def tag_attributes(tags)
    tags.transform_keys { |key| "riffer.tag.#{key}" }
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Symbol?, String?) -> void
  def record_finish_reason(span, reason, raw)
    return unless reason

    span.set_attribute("gen_ai.response.finish_reasons", [reason.to_s])
    span.set_attribute("riffer.finish_reason.raw", raw) if raw && raw != reason.to_s
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Riffer::Tracing::StreamRecorder) -> void
  def record_stream_outcome(span, recorder)
    Riffer::Tracing.record_usage(span, recorder.token_usage)
    record_finish_reason(span, recorder.finish_reason, recorder.raw_finish_reason)
    time_to_first_chunk = recorder.time_to_first_chunk
    span.set_attribute("gen_ai.response.time_to_first_chunk", time_to_first_chunk) if time_to_first_chunk
    capture_output(span, content: recorder.content, tool_calls: recorder.tool_calls,
                         finish_reason: recorder.finish_reason,)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Array[Riffer::Messages::Base]) -> void
  def capture_input(span, messages)
    return unless capture_messages?(span)

    span.set_attribute("gen_ai.input.messages", Riffer::Tracing::Capture.input_messages(messages))
    system_instructions = Riffer::Tracing::Capture.system_instructions(messages)
    span.set_attribute("gen_ai.system_instructions", system_instructions) if system_instructions
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), content: String?, tool_calls: Array[Riffer::Messages::Assistant::ToolCall], finish_reason: Symbol?) -> void
  def capture_output(span, content:, tool_calls:, finish_reason:)
    return unless capture_messages?(span)

    span.set_attribute("gen_ai.output.messages",
                       Riffer::Tracing::Capture.output_messages(content: content, tool_calls: tool_calls,
                                                                finish_reason: finish_reason,),)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span)) -> bool
  def capture_messages?(span)
    Riffer.config.tracing.capture_messages && span.recording?
  end

  #--
  #: (Riffer::Providers::_EventSink, Riffer::Providers::FinishReason?) -> void
  def yield_finish_reason(yielder, finish_reason)
    return unless finish_reason

    yielder << Riffer::StreamEvents::FinishReasonDone.new(finish_reason: finish_reason.reason,
                                                          raw_finish_reason: finish_reason.raw,)
  end

  #--
  #: (String) -> Hash[Symbol, untyped]?
  def parse_structured_output(content)
    JSON.parse(content, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  #--
  #: ((String | Hash[String, untyped])?) -> Hash[String, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    arguments.is_a?(String) ? JSON.parse(arguments) : arguments
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> Array[Riffer::Messages::Base]
  def merge_consecutive_messages(messages)
    messages.chunk { |msg| msg.role }.flat_map do |role, group|
      next group if role == :tool || group.size == 1

      group.inject { |merged, msg| merged + msg }
    end
  end

  #--
  #: (prompt: String?, system: String?, messages: Array[Hash[Symbol | String, untyped] | Riffer::Messages::Base]?) -> void
  def validate_input!(prompt:, system:, messages:)
    if messages.nil?
      raise Riffer::ArgumentError, "prompt is required when messages is not provided" if prompt.nil?
    else
      raise Riffer::ArgumentError, "cannot provide both prompt and messages" if prompt
      raise Riffer::ArgumentError, "cannot provide both system and messages" if system
    end
  end

  #--
  #: (prompt: String?, system: String?, messages: Array[Hash[Symbol, untyped] | Riffer::Messages::Base]?, ?files: Array[Hash[Symbol, untyped] | Riffer::Messages::FilePart]?) -> Array[Riffer::Messages::Base]
  def normalize_messages(prompt:, system:, messages:, files: nil)
    if messages && files && !files.empty?
      raise Riffer::ArgumentError, "cannot provide both files and messages; attach files to individual messages instead"
    end

    return messages.map { |msg| Riffer::Messages::Base.from_hash(msg) } if messages

    result = [] #: Array[Riffer::Messages::Base]
    result << Riffer::Messages::System.new(system) if system
    file_parts = (files || []).map { |f| Riffer::Messages::FilePart.from_hash(f) }
    prompt_text = prompt #: String
    result << Riffer::Messages::User.new(prompt_text, files: file_parts)
    result
  end

  #--
  #: (Array[Riffer::Messages::Base]) -> void
  def validate_normalized_messages!(messages)
    has_user = messages.any? { |msg| msg.is_a?(Riffer::Messages::User) }
    raise Riffer::ArgumentError, "messages must include at least one user message" unless has_user
  end
end
