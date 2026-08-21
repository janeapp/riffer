# frozen_string_literal: true
# rbs_inline: enabled

require "json"
require "net/http"
require "uri"

# HTTP transport for the Gemini REST API. Riffer builds one from the
# configured +api_key+ by default; construct your own to tune the HTTP knobs
# and assign it to <tt>Riffer.config.gemini.client</tt>. Any object
# implementing +post+ and +post_stream+ with these contracts works there —
# the class is a default implementation, not a required base.
#
#   Riffer.configure do |config|
#     config.gemini.client = Riffer::Providers::Gemini::Client.new(
#       api_key: ENV["GEMINI_API_KEY"],
#       read_timeout: 120
#     )
#   end
class Riffer::Providers::Gemini::Client
  # @rbs @api_key: String?
  # @rbs @base_url: String
  # @rbs @open_timeout: Integer
  # @rbs @read_timeout: Integer
  # @rbs @write_timeout: Integer?
  # @rbs @proxy_address: String?
  # @rbs @proxy_port: Integer?

  DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com" #: String
  DEFAULT_OPEN_TIMEOUT = 10 #: Integer
  DEFAULT_READ_TIMEOUT = 60 #: Integer

  #: (?api_key: String?, ?base_url: String, ?open_timeout: Integer, ?read_timeout: Integer, ?write_timeout: Integer?, ?proxy_address: String?, ?proxy_port: Integer?) -> void
  def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, open_timeout: DEFAULT_OPEN_TIMEOUT,
                 read_timeout: DEFAULT_READ_TIMEOUT, write_timeout: nil,
                 proxy_address: nil, proxy_port: nil)
    @api_key = api_key
    @base_url = base_url
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    @write_timeout = write_timeout
    @proxy_address = proxy_address
    @proxy_port = proxy_port
  end

  # POSTs a JSON body to an API path and returns the parsed response hash.
  # Raises Riffer::Error when the API responds with a non-success status.
  #--
  #: (String, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def post(path, body)
    uri = URI("#{@base_url}/#{path}")
    response = start_http(uri) { |http| http.request(build_request(uri, body)) }
    handle_api_error!(response) unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body, symbolize_names: true)
  end

  # POSTs a JSON body to an API path, yielding raw response body chunks as
  # they arrive. Raises Riffer::Error when the API responds with a
  # non-success status.
  #--
  #: (String, Hash[Symbol, untyped]) { (String) -> void } -> void
  def post_stream(path, body, &block)
    uri = URI("#{@base_url}/#{path}")
    start_http(uri) do |http|
      http.request(build_request(uri, body)) do |response|
        handle_api_error!(response) unless response.is_a?(Net::HTTPSuccess)

        begin
          response.read_body(&block)
        rescue IOError
          # A pre-buffered body (VCR/WebMock playback) raises IOError on a
          # streaming read; hand over the full body instead.
          yield(response.body)
        end
      end
    end
  end

  private

  #--
  #: (URI::Generic, Hash[Symbol, untyped]) -> Net::HTTP::Post
  def build_request(uri, body)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-goog-api-key"] = @api_key
    request.body = body.to_json
    request
  end

  #--
  #: [R] (URI::Generic) { (Net::HTTP) -> R } -> R
  def start_http(uri, &)
    host = uri.hostname #: String
    options = {
      use_ssl: uri.scheme == "https",
      open_timeout: @open_timeout,
      read_timeout: @read_timeout,
    } #: Hash[Symbol, untyped]
    options[:write_timeout] = @write_timeout if @write_timeout

    if @proxy_address
      Net::HTTP.start(host, uri.port, @proxy_address, @proxy_port, nil, nil, **options, &)
    else
      Net::HTTP.start(host, uri.port, **options, &)
    end
  end

  #--
  #: (Net::HTTPResponse) -> void
  def handle_api_error!(response)
    parsed = begin
      JSON.parse(response.body, symbolize_names: true)
    rescue JSON::ParserError
      { message: response.body }
    end
    error_message = parsed.dig(:error, :message) || parsed[:message] || response.body
    raise Riffer::Error, "Gemini API error (#{response.code}): #{error_message}"
  end
end
