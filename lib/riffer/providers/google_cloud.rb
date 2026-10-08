# frozen_string_literal: true
# rbs_inline: enabled

# Vertex AI (Gemini Enterprise Agent Platform). Gemini models share the
# Gemini Developer API's request and response bodies, so this inherits the
# Gemini provider's conversion and only swaps the transport and resource paths.
class Riffer::Providers::GoogleCloud < Riffer::Providers::Gemini
  # Vertex model ids may carry an +@version+ suffix.
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
