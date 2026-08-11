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
  #: (**untyped) -> void
  def initialize(**options)
    api_key = options.fetch(:api_key) do
      Riffer.config.azure_openai.api_key || ENV.fetch("AZURE_OPENAI_API_KEY", nil)
    end
    base_url = options.fetch(:base_url) do
      Riffer.config.azure_openai.endpoint || ENV.fetch("AZURE_OPENAI_ENDPOINT", nil)
    end
    super(api_key: api_key, base_url: base_url, **options.except(:api_key, :base_url))
  end
end
