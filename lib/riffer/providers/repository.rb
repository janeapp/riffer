# frozen_string_literal: true
# rbs_inline: enabled

# Registry for finding provider classes by identifier.
class Riffer::Providers::Repository
  # Mapping of provider identifiers to provider class lambdas.
  REPO = {
    amazon_bedrock: -> { Riffer::Providers::AmazonBedrock },
    anthropic: -> { Riffer::Providers::Anthropic },
    openai: -> { Riffer::Providers::OpenAI },
    test: -> { Riffer::Providers::Test }
  }.freeze #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  # Finds a provider class by identifier.
  #
  #: ((String | Symbol)) -> singleton(Riffer::Providers::Base)?
  def self.find(identifier)
    REPO.fetch(identifier.to_sym, nil)&.call
  end
end
