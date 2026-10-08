# frozen_string_literal: true
# rbs_inline: enabled

require "json"
require "net/http"
require "uri"

# <tt>Riffer.config.google_cloud.client</tt> accepts any object implementing +post+ and +post_stream+
# with these contracts; this class is the default, not a required base. Paths are relative to
# the client's <tt>v1/projects/{project_id}/locations/{location}</tt> resource.
class Riffer::Providers::GoogleCloud::Client
  # @rbs @project_id: String
  # @rbs @location: String
  # @rbs @credentials: untyped
  # @rbs @base_url: String
  # @rbs @open_timeout: Integer
  # @rbs @read_timeout: Integer
  # @rbs @write_timeout: Integer?
  # @rbs @proxy_address: String?
  # @rbs @proxy_port: Integer?
  # @rbs self.@application_default_credentials: untyped

  SCOPE = "https://www.googleapis.com/auth/cloud-platform" #: String
  DEFAULT_OPEN_TIMEOUT = 10 #: Integer
  DEFAULT_READ_TIMEOUT = 60 #: Integer

  # Both are interpolated into the endpoint's host or path.
  VALID_PROJECT_ID_PATTERN = /\A[a-z0-9.:-]+\z/ #: Regexp
  VALID_LOCATION_PATTERN = /\A[a-z0-9-]+\z/ #: Regexp

  # googleauth's metadata-server lookups (GCE, Cloud Run, GKE) go through a
  # process-wide google-cloud-env cache that detects reentrancy by Thread, so
  # two fibers inside it at once raise ThreadError. Every googleauth call that
  # can reach it holds this lock; Ruby's Mutex is fiber-aware, so waiters yield
  # to the scheduler instead of blocking the thread.
  AUTH_LOCK = Mutex.new #: Thread::Mutex

  # Memoized process-wide so every client shares one token cache.
  #--
  #: () -> untyped
  def self.application_default_credentials
    AUTH_LOCK.synchronize do
      @application_default_credentials ||= begin
        Riffer::Helpers::Dependencies.depends_on("googleauth")
        Google::Auth.get_application_default([SCOPE])
      end
    end
  end

  #--
  #: (location: String) -> String
  def self.base_url_for(location:)
    case location
    when "global" then "https://aiplatform.googleapis.com"
    when "us", "eu" then "https://aiplatform.#{location}.rep.googleapis.com"
    else "https://#{location}-aiplatform.googleapis.com"
    end
  end

  # +credentials+ is a googleauth credentials object (anything responding to
  # +apply!+); +nil+ resolves Application Default Credentials.
  #--
  #: (project_id: String, location: String, ?credentials: untyped, ?base_url: String?, ?open_timeout: Integer, ?read_timeout: Integer, ?write_timeout: Integer?, ?proxy_address: String?, ?proxy_port: Integer?) -> void
  def initialize(project_id:, location:, credentials: nil, base_url: nil,
                 open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT,
                 write_timeout: nil, proxy_address: nil, proxy_port: nil)
    validate!(project_id, VALID_PROJECT_ID_PATTERN, "project_id")
    validate!(location, VALID_LOCATION_PATTERN, "location")

    @project_id = project_id
    @location = location
    @credentials = credentials
    @base_url = base_url || self.class.base_url_for(location: location)
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    @write_timeout = write_timeout
    @proxy_address = proxy_address
    @proxy_port = proxy_port
  end

  # Raises Riffer::Error on a non-success status.
  #--
  #: (String, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def post(path, body)
    uri = resource_uri(path)
    response = start_http(uri) { |http| http.request(build_request(uri, body)) }
    handle_api_error!(response) unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body, symbolize_names: true)
  end

  # Raises Riffer::Error on a non-success status.
  #--
  #: (String, Hash[Symbol, untyped]) { (String) -> void } -> void
  def post_stream(path, body, &block)
    uri = resource_uri(path)
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
  #: (String, Regexp, String) -> void
  def validate!(value, pattern, attribute)
    return if value.is_a?(String) && value.match?(pattern)

    raise Riffer::ArgumentError, "Invalid #{attribute}: #{value.inspect}"
  end

  #--
  #: (String) -> URI::Generic
  def resource_uri(path)
    URI("#{@base_url}/v1/projects/#{@project_id}/locations/#{@location}/#{path}")
  end

  # googleauth's +apply!+ refreshes only a missing or near-expiry token, so
  # fibers queued behind a refresh reuse its result.
  #--
  #: () -> String
  def authorization
    credentials = @credentials || self.class.application_default_credentials
    headers = {} #: Hash[Symbol, String]
    AUTH_LOCK.synchronize { credentials.apply!(headers) }
  end

  #--
  #: (URI::Generic, Hash[Symbol, untyped]) -> Net::HTTP::Post
  def build_request(uri, body)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Authorization"] = authorization
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
    # streamRawPredict wraps its error object in a JSON array.
    parsed = parsed.first if parsed.is_a?(Array) && parsed.first.is_a?(Hash)
    error_message = parsed.dig(:error, :message) || parsed[:message] || response.body
    raise Riffer::Error, "Google Cloud API error (#{response.code}): #{error_message}"
  end
end
