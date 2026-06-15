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
    depends_on "openai"

    api_key = options.fetch(:api_key) {
      Riffer.config.azure_openai.api_key || ENV["AZURE_OPENAI_API_KEY"]
    }
    base_url = options.fetch(:base_url) {
      Riffer.config.azure_openai.endpoint || ENV["AZURE_OPENAI_ENDPOINT"]
    }
    @client = ::OpenAI::Client.new(
      api_key: api_key,
      base_url: base_url,
      **options.except(:api_key, :base_url)
    )
  end
end
