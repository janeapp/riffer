# Registry for finding provider classes by identifier.
class Riffer::Providers::Repository
  # Mapping of provider identifiers to provider class lambdas.
  REPO = {
    amazon_bedrock: -> { Riffer::Providers::AmazonBedrock },
    anthropic: -> { Riffer::Providers::Anthropic },
    openai: -> { Riffer::Providers::OpenAI },
    test: -> { Riffer::Providers::Test }
  }.freeze

  class << self
    # Finds a provider class by identifier.
    #
    # identifier:: String or Symbol - the identifier to search for
    #
    # Returns Class or nil - the provider class, or nil if not found.
    def find(identifier)
      REPO.fetch(identifier.to_sym, nil)&.call
    end
  end
end
