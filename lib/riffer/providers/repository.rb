# frozen_string_literal: true
# rbs_inline: enabled

# Registry for finding provider classes by identifier.
module Riffer::Providers::Repository
  extend self

  # @rbs @key_for: Hash[singleton(Riffer::Providers::Base), Symbol]?

  REPO = {
    amazon_bedrock: -> { Riffer::Providers::AmazonBedrock },
    anthropic: -> { Riffer::Providers::Anthropic },
    azure_openai: -> { Riffer::Providers::AzureOpenAI },
    gemini: -> { Riffer::Providers::Gemini },
    openai: -> { Riffer::Providers::OpenAI },
    openrouter: -> { Riffer::Providers::OpenRouter },
    mock: -> { Riffer::Providers::Mock }
  }.freeze #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  # Finds a provider class by identifier.
  #
  #--
  #: ((String | Symbol)) -> singleton(Riffer::Providers::Base)?
  def find(identifier)
    REPO.fetch(identifier.to_sym, nil)&.call
  end

  # Returns the registry identifier for a provider class, or nil when unregistered.
  #--
  #: (singleton(Riffer::Providers::Base)) -> Symbol?
  def key_for(provider_class)
    (@key_for ||= REPO.to_h { |key, factory| [factory.call, key] })[provider_class]
  end
end
