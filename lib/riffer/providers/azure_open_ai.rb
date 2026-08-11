# frozen_string_literal: true
# rbs_inline: enabled

# Azure OpenAI provider for GPT models hosted on Azure. Requires the +openai+
# gem. Credentials resolve from kwargs, then config, then
# +AZURE_OPENAI_API_KEY+ / +AZURE_OPENAI_ENDPOINT+.
class Riffer::Providers::AzureOpenAI < Riffer::Providers::OpenAI
  # The GenAI semconv well-known provider name.
  #--
  #: () -> String
  def self.semconv_provider_name
    "azure.ai.openai"
  end

  #--
  #: (?api_key: String?, ?endpoint: String?) -> void
  def initialize(api_key: nil, endpoint: nil)
    super(api_key: api_key, base_url: endpoint)
  end

  private

  #--
  #: () -> untyped
  def provider_config
    Riffer.config.azure_openai
  end

  #--
  #: () -> untyped
  def build_default_client
    api_key = @api_key || Riffer.config.azure_openai.api_key || ENV.fetch("AZURE_OPENAI_API_KEY", nil)
    base_url = @base_url || Riffer.config.azure_openai.endpoint || ENV.fetch("AZURE_OPENAI_ENDPOINT", nil)
    ::OpenAI::Client.new(api_key: api_key, base_url: base_url)
  end
end
