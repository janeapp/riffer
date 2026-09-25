# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Providers::Repository
  extend self

  # @rbs @registrations: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]
  # @rbs @options: Hash[Symbol, Hash[Symbol, untyped]]

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
  @options = {} #: Hash[Symbol, Hash[Symbol, untyped]]

  # Not synchronized — register during boot, before concurrent generation
  # begins. +options+ are passed to +new+ on every build.
  #--
  #: ((String | Symbol), **untyped) { () -> singleton(Riffer::Providers::Base) } -> void
  def register(identifier, **options, &factory)
    raise Riffer::ArgumentError, "key: is set from the identifier, not an option" if options.key?(:key)

    key = identifier.to_sym
    @registrations[key] = factory
    @options[key] = options
  end

  #--
  #: ((String | Symbol)) -> void
  def unregister(identifier)
    key = identifier.to_sym
    @registrations.delete(key)
    @options.delete(key)
  end

  #--
  #: ((String | Symbol)) -> singleton(Riffer::Providers::Base)?
  def find(identifier)
    key = identifier.to_sym
    (@registrations[key] || REPO[key])&.call
  end

  #--
  #: ((String | Symbol)) -> Riffer::Providers::Base?
  def build(identifier)
    key = identifier.to_sym
    provider_class = find(key)
    return nil unless provider_class

    options = @options[key] || {} #: Hash[Symbol, untyped]
    provider_class.new(key: key, **options)
  end
end
