# frozen_string_literal: true
# rbs_inline: enabled

# Gemini models on Gemini Enterprise Agent Platform (formerly Vertex AI). The
# request and response bodies match the Gemini Developer API's, so this only
# swaps the transport, the resource paths and the structured output field.
class Riffer::Providers::GoogleCloud < Riffer::Providers::Gemini
  # Agent Platform model ids may carry an +@version+ suffix.
  VALID_MODEL_PATTERN = /\A[a-zA-Z0-9._@-]+\z/ #: Regexp

  REASONING_FORMAT = "google-cloud-generate-content-v1" #: String

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
  #: () -> untyped
  def build_client
    Riffer::Providers::GoogleCloud::Client.from_config(Riffer.config.google_cloud)
  end

  #--
  #: () -> String
  def reasoning_format
    REASONING_FORMAT
  end

  # Agent Platform declares responseFormat as a repeated field.
  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def structured_output_config(json_schema)
    { responseFormat: [{ text: { mimeType: "APPLICATION_JSON", schema: json_schema } }] }
  end

  #--
  #: (String, String) -> String
  def api_path(model, method)
    validate_model!(model)
    "publishers/google/models/#{model}:#{method}"
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
