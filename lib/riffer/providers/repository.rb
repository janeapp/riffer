# frozen_string_literal: true
# rbs_inline: enabled

# Resolves provider classes by identifier, combining the built-in REPO with
# consumer registrations added through +register+. Registration is not
# synchronized — register during boot, before concurrent generation begins.
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
    mock: -> { Riffer::Providers::Mock }
  }.freeze #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  @registrations = {} #: Hash[Symbol, ^() -> singleton(Riffer::Providers::Base)]

  # Registers a custom provider under +identifier+, resolved lazily by the block.
  # Takes precedence over a built-in sharing the identifier.
  #
  #   Riffer::Providers::Repository.register(:jane) { MyApp::JaneProvider }
  #
  # Raises Riffer::ArgumentError when called without a block.
  #
  #--
  #: ((String | Symbol)) { () -> singleton(Riffer::Providers::Base) } -> void
  def register(identifier, &factory)
    raise Riffer::ArgumentError, "register requires a block returning a provider class" unless factory

    @registrations[identifier.to_sym] = factory
    @key_for = nil
  end

  # Removes a custom registration by identifier, leaving any built-in of the
  # same name intact.
  #--
  #: ((String | Symbol)) -> void
  def unregister(identifier)
    @registrations.delete(identifier.to_sym)
    @key_for = nil
  end

  # Finds a provider class by identifier, preferring a custom registration over
  # a built-in of the same name.
  #
  #--
  #: ((String | Symbol)) -> singleton(Riffer::Providers::Base)?
  def find(identifier)
    key = identifier.to_sym
    (@registrations[key] || REPO[key])&.call
  end

  # Returns the registry identifier for a provider class, or nil when unregistered.
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
