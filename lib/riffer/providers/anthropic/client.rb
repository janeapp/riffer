# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::Anthropic::Client < Riffer::HTTP::Client
  # @rbs @api_key: String
  # @rbs @base_url: String

  DEFAULT_BASE_URL = "https://api.anthropic.com" #: String

  # Override with an anthropic-version entry in +headers+.
  DEFAULT_ANTHROPIC_VERSION = "2026-10-21" #: String

  #--
  #: (api_key: String, ?base_url: String, ?headers: Hash[String, String], ?connection: Faraday::Connection?) -> void
  def initialize(api_key:, base_url: DEFAULT_BASE_URL, headers: {}, connection: nil)
    super(headers: headers, connection: connection)
    @api_key = api_key
    @base_url = base_url.chomp("/")
  end

  private

  #--
  #: (String) -> String
  def url_for(path)
    "#{@base_url}/#{path}"
  end

  #--
  #: () -> Hash[String, String]
  def headers
    { "authorization" => "Bearer #{@api_key}", "anthropic-version" => DEFAULT_ANTHROPIC_VERSION }
  end

  #--
  #: () -> String
  def error_label
    "Anthropic"
  end

  #--
  #: (Hash[Symbol, untyped], String) -> String
  def error_message(parsed, raw)
    error = parsed[:error]
    return super unless error.is_a?(Hash) && error[:type] && error[:message]

    "#{error[:type]}: #{error[:message]}"
  end
end
