# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::AzureOpenAI < Riffer::Providers::OpenAI
  #--
  #: () -> String
  def self.semconv_provider_name
    "azure.ai.openai"
  end

  private

  #--
  #: () -> untyped
  def global_client
    Riffer.config.azure_openai.client
  end

  #--
  #: () -> untyped
  def build_client
    api_key = Riffer.config.azure_openai.api_key || ENV.fetch("AZURE_OPENAI_API_KEY", nil)
    base_url = Riffer.config.azure_openai.endpoint || ENV.fetch("AZURE_OPENAI_ENDPOINT", nil)
    # Pass nils rather than omitting them: an omitted argument lets the SDK fall
    # back to OPENAI_API_KEY / OPENAI_BASE_URL, sending Azure traffic and an
    # OpenAI credential elsewhere. A nil raises in the SDK instead.
    ::OpenAI::Client.new(api_key: api_key, base_url: base_url)
  end

  # Azure resolves and decrypts reasoning items only within the resource that produced them.
  #--
  #: () -> String
  def reasoning_format
    "azure-openai-v1"
  end
end
