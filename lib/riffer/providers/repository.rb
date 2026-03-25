# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::Repository
  REPO = {
    amazon_bedrock: -> { Riffer::Providers::AmazonBedrock },
    anthropic: -> { Riffer::Providers::Anthropic },
    azure_openai: -> { Riffer::Providers::AzureOpenAI },
    openai: -> { Riffer::Providers::OpenAI },
    mock: -> { Riffer::Providers::Mock }
  }.freeze #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  #: ((String | Symbol)) -> singleton(Riffer::Providers::Base)?
  def self.find(identifier)
    REPO.fetch(identifier.to_sym, nil)&.call
  end
end
