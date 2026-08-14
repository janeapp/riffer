# frozen_string_literal: true
# rbs_inline: enabled

# Azure OpenAI provider for GPT models hosted on Azure. Requires the +openai+
# gem. Credentials resolve from config, then +AZURE_OPENAI_API_KEY+ /
# +AZURE_OPENAI_ENDPOINT+.
class Riffer::Providers::AzureOpenAI < Riffer::Providers::OpenAI
  # The GenAI semconv well-known provider name.
  #--
  #: () -> String
  def self.semconv_provider_name
    "azure.ai.openai"
  end

  private

  #--
  #: () -> untyped
  def provider_config
    Riffer.config.azure_openai
  end

  # Deliberately not compacted: this borrows the OpenAI SDK to talk to Azure, so
  # omitting an unset argument would let the SDK fall back to +OPENAI_API_KEY+
  # and +OPENAI_BASE_URL+ — sending Azure traffic, and an OpenAI credential, to
  # whatever those name. Passing nil raises in the SDK instead.
  #--
  #: () -> untyped
  def build_client
    api_key = Riffer.config.azure_openai.api_key || ENV.fetch("AZURE_OPENAI_API_KEY", nil)
    base_url = Riffer.config.azure_openai.endpoint || ENV.fetch("AZURE_OPENAI_ENDPOINT", nil)
    ::OpenAI::Client.new(api_key: api_key, base_url: base_url)
  end
end
