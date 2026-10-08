# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Vertex AI (Gemini Enterprise Agent Platform). Gemini models share the
# Gemini Developer API's request and response bodies, so this inherits the
# Gemini provider's conversion and only swaps the transport and resource paths.
# Claude models speak the Anthropic Messages format through rawPredict.
class Riffer::Providers::GoogleCloud < Riffer::Providers::Gemini
  # Vertex model ids may carry an +@version+ suffix.
  VALID_MODEL_PATTERN = /\A[a-zA-Z0-9._@-]+\z/ #: Regexp

  # Vertex's stand-in for the anthropic-version header, sent in the body.
  ANTHROPIC_VERSION = "vertex-2023-10-16" #: String

  #--
  #: (?String?) -> singleton(Riffer::Skills::Adapter)
  def self.skills_adapter(model = nil)
    return Riffer::Skills::XmlAdapter if model && claude_model?(model)

    Riffer::Skills::MarkdownAdapter
  end

  #--
  #: () -> String
  def self.semconv_provider_name
    "gcp.vertex_ai"
  end

  #--
  #: (String?) -> bool
  def self.claude_model?(model)
    model.to_s.start_with?("claude-")
  end

  private

  #--
  #: () -> untyped
  def global_client
    Riffer.config.google_cloud.client
  end

  #--
  #: () -> untyped
  def build_client
    config = Riffer.config.google_cloud
    project_id = config.project_id
    raise Riffer::ArgumentError, "Riffer.config.google_cloud.project_id must be set" unless project_id

    Riffer::Providers::GoogleCloud::Client.new(
      project_id: project_id,
      location: config.location,
      credentials: config.credentials,
    )
  end

  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    return super unless self.class.claude_model?(model)

    {
      model: model,
      anthropic_version: ANTHROPIC_VERSION,
      **Riffer::Wire::Anthropic::Request.build(messages, options),
    }
  end

  #--
  #: (Hash[Symbol, untyped]) -> (Hash[Symbol, untyped] | Riffer::Wire::Anthropic::Response)
  def execute_generate(params)
    model = params[:model]
    return super unless self.class.claude_model?(model)

    body = client.post(anthropic_path(model, "rawPredict"), params.except(:model))
    Riffer::Wire::Anthropic::Response.new(body, tools: @current_tools)
  end

  #--
  #: (Hash[Symbol, untyped], Riffer::Providers::_EventSink) -> void
  def execute_stream(params, yielder)
    model = params[:model]
    return super unless self.class.claude_model?(model)

    stream = Riffer::Wire::Anthropic::Stream.new(tools: @current_tools)
    decoder = Riffer::Wire::SSE.new
    body = params.except(:model).merge(stream: true)

    client.post_stream(anthropic_path(model, "streamRawPredict"), body) do |chunk|
      decoder.feed(chunk) { |data, _event| stream.handle(JSON.parse(data, symbolize_names: true), yielder) }
    end

    message = stream.finish!
    yield_finish_reason(yielder, message.finish_reason)
    usage = message.token_usage
    yielder << Riffer::StreamEvents::TokenUsageDone.new(token_usage: apply_pricing(usage)) if usage
  end

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Wire::Anthropic::Response)) -> String
  def extract_content(response)
    return response.content if response.is_a?(Riffer::Wire::Anthropic::Response)

    super
  end

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Wire::Anthropic::Response)) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    return response.tool_calls if response.is_a?(Riffer::Wire::Anthropic::Response)

    super
  end

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Wire::Anthropic::Response)) -> Array[Riffer::Messages::Assistant::ReasoningPart]
  def extract_reasoning(response)
    return response.reasoning if response.is_a?(Riffer::Wire::Anthropic::Response)

    super
  end

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Wire::Anthropic::Response)) -> Riffer::Providers::TokenUsage?
  def extract_token_usage(response)
    return super unless response.is_a?(Riffer::Wire::Anthropic::Response)

    usage = response.token_usage
    usage && apply_pricing(usage)
  end

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Wire::Anthropic::Response)) -> Riffer::Providers::FinishReason?
  def extract_finish_reason(response)
    return response.finish_reason if response.is_a?(Riffer::Wire::Anthropic::Response)

    super
  end

  #--
  #: (String, String) -> String
  def api_path(model, method)
    validate_model!(model)
    "publishers/google/models/#{model}:#{method}"
  end

  #--
  #: (String, String) -> String
  def anthropic_path(model, method)
    validate_model!(model)
    "publishers/anthropic/models/#{model}:#{method}"
  end

  #--
  #: (String) -> void
  def validate_model!(model)
    return if model.match?(VALID_MODEL_PATTERN)

    raise Riffer::ArgumentError,
          "Invalid model name: #{model.inspect}. Model must contain only alphanumeric characters, " \
          "hyphens, dots, underscores, and @."
  end
end
