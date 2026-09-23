# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Providers::Repository
  extend self

  # @rbs @registrations: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]
  # @rbs @key_for: Hash[singleton(Riffer::Providers::Base), Symbol]?

  REPO = {
    amazon_bedrock: -> { Riffer::Providers::AmazonBedrock },
    anthropic: -> { Riffer::Providers::Anthropic },
    azure_openai: -> { Riffer::Providers::AzureOpenAI },
    gemini: -> { Riffer::Providers::Gemini },
    openai: -> { Riffer::Providers::OpenAI },
    openrouter: -> { Riffer::Providers::OpenRouter },
    mock: -> { Riffer::Providers::Mock },
  }.freeze #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  @registrations = {} #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  # Not synchronized — register during boot, before concurrent generation
  # begins.
  #
  #   Riffer::Providers::Repository.register(:jane) { MyApp::JaneProvider }
  #
  #--
  #: ((String | Symbol)) { () -> singleton(Riffer::Providers::Base) } -> void
  def register(identifier, &factory)
    @registrations[identifier.to_sym] = factory
    @key_for = nil
  end

  #--
  #: ((String | Symbol)) -> void
  def unregister(identifier)
    @registrations.delete(identifier.to_sym)
    @key_for = nil
  end

  #--
  #: ((String | Symbol)) -> singleton(Riffer::Providers::Base)?
  def find(identifier)
    key = identifier.to_sym
    (@registrations[key] || REPO[key])&.call
  end

  #--
  #: (singleton(Riffer::Providers::Base)) -> Symbol?
  def key_for(provider_class)
    (@key_for ||= build_key_index)[provider_class]
  end

  private

  #--
  #: () -> Hash[singleton(Riffer::Providers::Base), Symbol]
  def build_key_index
    REPO.merge(@registrations).to_h { |key, factory| [factory.call, key] }
  end
end
