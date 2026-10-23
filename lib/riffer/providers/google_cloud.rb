# frozen_string_literal: true
# rbs_inline: enabled

# Gemini models on Gemini Enterprise Agent Platform (formerly Vertex AI). The
# request and response bodies match the Gemini Developer API's, so this only
# swaps the transport, the resource paths and the structured output field.
class Riffer::Providers::GoogleCloud < Riffer::Providers::Gemini
  # Agent Platform model ids may carry an +@version+ suffix.
  VALID_MODEL_PATTERN = /\A[a-zA-Z0-9._@-]+\z/ #: Regexp

  REASONING_FORMAT = "google-cloud-generate-content-v1" #: String

  # Agent Platform label keys and values: at most 63 characters of lowercase
  # letters, digits, underscores and dashes; keys start with a letter.
  LABEL_MAX_LENGTH = 63 #: Integer
  LABEL_INVALID_CHARACTERS = /[^\p{Ll}\p{Lo}\p{N}_-]/ #: Regexp

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

  # Tags go out as request labels, merged over any +labels+ model option.
  #--
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    params = super(messages, model, options.except(:labels))
    labels = (options[:labels] || {}).transform_keys(&:to_s).merge(tag_labels(options[:tags] || {}))
    params[:labels] = labels unless labels.empty?
    params
  end

  # Rewrites tags into valid labels (downcased, invalid characters replaced by
  # an underscore, cut to 63 characters) and drops keys that don't start with
  # a letter, so a tag like agent: "support/triage_agent" can't fail the call.
  #--
  #: (Hash[untyped, untyped]) -> Hash[String, String]
  def tag_labels(tags)
    labels = {} #: Hash[String, String]
    tags.each do |key, value|
      next if value.nil?

      label_key = to_label(key)
      labels[label_key] = to_label(value) if label_key.match?(/\A\p{L}/)
    end
    labels
  end

  #--
  #: (untyped) -> String
  def to_label(value)
    value.to_s.downcase.gsub(LABEL_INVALID_CHARACTERS, "_")[0, LABEL_MAX_LENGTH].to_s
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
