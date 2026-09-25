# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Providers::Repository
  extend self

  # @rbs @registrations: Hash[Symbol, ^() -> (singleton(Riffer::Providers::Base) | Riffer::Providers::Base)]
  # @rbs @builtin_keys: Hash[singleton(Riffer::Providers::Base), Symbol]?

  REPO = {
    amazon_bedrock: -> { Riffer::Providers::AmazonBedrock },
    anthropic: -> { Riffer::Providers::Anthropic },
    azure_openai: -> { Riffer::Providers::AzureOpenAI },
    gemini: -> { Riffer::Providers::Gemini },
    openai: -> { Riffer::Providers::OpenAI },
    openrouter: -> { Riffer::Providers::OpenRouter },
    mock: -> { Riffer::Providers::Mock },
  }.freeze #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  @registrations = {} #: Hash[Symbol, ^() -> (singleton(Riffer::Providers::Base) | Riffer::Providers::Base)]

  # Not synchronized — register during boot, before concurrent generation
  # begins.
  #--
  #: ((String | Symbol)) { () -> (singleton(Riffer::Providers::Base) | Riffer::Providers::Base) } -> void
  def register(identifier, &factory)
    @registrations[identifier.to_sym] = factory
  end

  #--
  #: ((String | Symbol)) -> void
  def unregister(identifier)
    @registrations.delete(identifier.to_sym)
  end

  #--
  #: ((String | Symbol)) -> (singleton(Riffer::Providers::Base) | Riffer::Providers::Base)?
  def find(identifier)
    key = identifier.to_sym
    (@registrations[key] || REPO[key])&.call
  end

  #--
  #: ((String | Symbol)) -> Riffer::Providers::Base?
  def build(identifier)
    found = find(identifier)
    return nil unless found

    provider = found.is_a?(Class) ? found.new : found
    provider.registry_key = identifier.to_sym
    provider
  end

  # Built-ins only: custom registrations are never called to build the index.
  #--
  #: (singleton(Riffer::Providers::Base)) -> Symbol?
  def builtin_key_for(provider_class)
    (@builtin_keys ||= REPO.to_h { |key, factory| [factory.call, key] })[provider_class]
  end
end
