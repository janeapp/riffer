class Riffer::Providers::Repository
  REPO = {
    openai: -> { Riffer::Providers::OpenAI },
    test: -> { Riffer::Providers::Test }
  }.freeze

  class << self
    # Finds a provider class by identifier
    # @param identifier [String, Symbol] the identifier to search for
    # @return [Class, nil] the provider class, or nil if not found
    def find(identifier)
      REPO.fetch(identifier.to_sym, nil)&.call
    end
  end
end
