# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Providers::Repository
  extend self

  # @rbs @registrations: Hash[Symbol, ^() -> (singleton(Riffer::Providers::Base) | Riffer::Providers::Base)]

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

  # The block runs on every call, so each build is a fresh provider — memoize
  # an expensive client yourself, e.g. behind the +client:+ Proc.
  #--
  #: ((String | Symbol)) -> Riffer::Providers::Base?
  def build(identifier)
    provider = find(identifier)
    provider.is_a?(Class) ? provider.new : provider
  end
end
