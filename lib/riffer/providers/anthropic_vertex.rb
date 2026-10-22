# frozen_string_literal: true
# rbs_inline: enabled

# Claude models on Gemini Enterprise Agent Platform (formerly Vertex AI), through
# its rawPredict endpoints. Shares config.google_cloud and GoogleCloud::Client
# with the google_cloud provider.
class Riffer::Providers::AnthropicVertex < Riffer::Providers::AnthropicCompatible::MessagesAPI
  # Agent Platform's stand-in for the anthropic-version header, sent in the body.
  ANTHROPIC_VERSION = "vertex-2023-10-16" #: String

  # Agent Platform model ids may carry an +@version+ suffix.
  VALID_MODEL_PATTERN = /\A[a-zA-Z0-9._@-]+\z/ #: Regexp

  #--
  #: () -> String
  def self.semconv_provider_name
    "gcp.vertex_ai"
  end

  private

  #--
  #: () -> untyped
  def global_client
    Riffer.config.google_cloud.client
  end

  #--
  #: () -> Riffer::Providers::GoogleCloud::Client
  def build_client
    Riffer::Providers::GoogleCloud::Client.from_config(Riffer.config.google_cloud)
  end

  # The model goes in the URL rather than the body.
  #--
  #: (String?, stream: bool) -> String
  def messages_path(model, stream:)
    validate_model!(model)
    "publishers/anthropic/models/#{model}:#{stream ? 'streamRawPredict' : 'rawPredict'}"
  end

  #--
  #: (Hash[Symbol, untyped], stream: bool) -> Hash[Symbol, untyped]
  def request_body(params, stream:)
    body = { anthropic_version: ANTHROPIC_VERSION, **params.except(:model) }
    stream ? body.merge(stream: true) : body
  end

  #--
  #: (String?) -> void
  def validate_model!(model)
    return if model.is_a?(String) && model.match?(VALID_MODEL_PATTERN)

    raise Riffer::ArgumentError,
          "Invalid model name: #{model.inspect}. Model must contain only alphanumeric characters, " \
          "hyphens, dots, underscores, and @."
  end
end
