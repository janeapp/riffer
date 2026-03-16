# frozen_string_literal: true
# rbs_inline: enabled

# Azure OpenAI provider for GPT models hosted on Azure.
#
# Requires the +openai+ gem to be installed.
#
# Credentials are resolved in order:
# 1. Keyword arguments (+api_key+, +base_url+)
# 2. Config (+Riffer.config.azure_openai.api_key+ / +.endpoint+)
# 3. Environment variables (+AZURE_OPENAI_API_KEY+ / +AZURE_OPENAI_ENDPOINT+)
#
#   Riffer::Providers::AzureOpenAI.new(
#     api_key: "key",
#     base_url: "https://my-resource.openai.azure.com"
#   )
#
class Riffer::Providers::AzureOpenAI < Riffer::Providers::OpenAI
  # Initializes the Azure OpenAI provider.
  #
  # +api_key+ - Azure OpenAI API key. Falls back to config, then +AZURE_OPENAI_API_KEY+.
  # +base_url+ - Azure OpenAI endpoint URL. Falls back to config, then +AZURE_OPENAI_ENDPOINT+.
  #
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
