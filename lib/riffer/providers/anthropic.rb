# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::Anthropic < Riffer::Providers::AnthropicCompatible::MessagesAPI
  #--
  #: () -> String
  def self.semconv_provider_name
    "anthropic"
  end

  private

  #--
  #: () -> untyped
  def client
    resolved = super
    if defined?(::Anthropic::Client) && resolved.is_a?(::Anthropic::Client) # steep:ignore UnknownConstant
      raise Riffer::ArgumentError,
            "config.anthropic.client now takes a Riffer::Providers::Anthropic::Client; pass timeouts, retries " \
            "and proxies through its connection: (see the Anthropic provider docs)"
    end

    resolved
  end

  #--
  #: () -> untyped
  def global_client
    Riffer.config.anthropic.client
  end

  #--
  #: () -> Riffer::Providers::Anthropic::Client
  def build_client
    config = Riffer.config.anthropic
    api_key = config.api_key || ENV.fetch("ANTHROPIC_API_KEY", nil)
    unless api_key
      raise Riffer::ArgumentError, "Anthropic requires an API key: set config.anthropic.api_key or ANTHROPIC_API_KEY"
    end

    base_url = config.base_url || ENV.fetch("ANTHROPIC_BASE_URL", nil) || Client::DEFAULT_BASE_URL
    Client.new(api_key: api_key, base_url: base_url)
  end
end
