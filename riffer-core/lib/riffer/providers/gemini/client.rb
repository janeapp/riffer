# frozen_string_literal: true
# rbs_inline: enabled

# <tt>Riffer.config.gemini.client</tt> accepts any object implementing +post+ and +post_stream+
# (see Riffer::HTTP::Client); this class is the default, not a required base.
class Riffer::Providers::Gemini::Client < Riffer::HTTP::Client
  # @rbs @api_key: String
  # @rbs @base_url: String

  DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com" #: String

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
    { "x-goog-api-key" => @api_key }
  end

  #--
  #: () -> String
  def error_label
    "Gemini"
  end
end
