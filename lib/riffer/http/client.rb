# frozen_string_literal: true
# rbs_inline: enabled

require "faraday"
require "json"

class Riffer::HTTP::Client
  # @rbs @connection: Faraday::Connection
  # @rbs @extra_headers: Hash[String, String]

  DEFAULT_OPEN_TIMEOUT = 10 #: Integer
  DEFAULT_READ_TIMEOUT = 600 #: Integer

  # Anthropic's header, on Vertex AI too. Gemini sends no request id header;
  # its id is +responseId+ in the response body.
  REQUEST_ID_HEADER = "request-id" #: String

  # +headers+ are sent on every request and win over the subclass's auth and
  # version headers, as do headers set on the +connection+.
  #--
  #: (?headers: Hash[String, String], ?connection: Faraday::Connection?) -> void
  def initialize(headers: {}, connection: nil)
    @extra_headers = headers
    @connection = connection || Faraday.new(
      request: { open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT },
    )
  end

  # Yields the request id header, or nil. Raises Riffer::APIError on a
  # non-success status.
  #--
  #: (String, Hash[Symbol, untyped]) ?{ (String?) -> void } -> Hash[Symbol, untyped]
  def post(path, body)
    response = request(path, body)
    request_id = response.headers[REQUEST_ID_HEADER]
    raise_api_error!(response.status, response.body, request_id) unless response.success?
    yield(request_id) if block_given?
    JSON.parse(response.body, symbolize_names: true)
  end

  # Yields each chunk with the request id header, or nil. Raises
  # Riffer::APIError on a non-success status; the error body is never yielded.
  #--
  #: (String, Hash[Symbol, untyped]) { (String, String?) -> void } -> void
  def post_stream(path, body, &)
    streamed = false
    yielded = false
    held = +""

    # A proc, not a lambda: httpx and typhoeus pass no env. Without one the
    # status is unknown until the response returns, so every chunk is held.
    on_data = proc do |chunk, bytes_received, env|
      streamed = true
      # Faraday restarts bytes_received on each attempt. httpx passes the chunk
      # size instead, so attempts are only told apart when there is an env.
      if env && bytes_received == chunk.bytesize
        if yielded
          raise Riffer::Error, "the stream restarted after data was delivered; " \
                               "retry middleware must not retry streaming requests mid-body"
        end
        held.clear
      end

      if env&.success?
        unless chunk.empty?
          yielded = true
          yield(chunk, env.response_headers[REQUEST_ID_HEADER])
        end
      else
        held << chunk
      end
    end

    response = request(path, body, on_data: on_data)
    unyielded = streamed ? held : response.body
    request_id = response.headers[REQUEST_ID_HEADER]
    raise_api_error!(response.status, unyielded, request_id) unless response.success?
    yield(unyielded, request_id) unless unyielded.empty?
  end

  private

  #--
  #: (String) -> String
  def url_for(path)
    raise NotImplementedError, "Subclasses must implement #url_for"
  end

  # Called per request so short-lived credentials can refresh.
  #--
  #: () -> Hash[String, String]
  def headers
    raise NotImplementedError, "Subclasses must implement #headers"
  end

  #--
  #: () -> String
  def error_label
    raise NotImplementedError, "Subclasses must implement #error_label"
  end

  #--
  #: (Hash[Symbol, untyped], String) -> String
  def error_message(parsed, raw)
    error = parsed[:error]
    case error
    when Hash then error[:message] || parsed[:message] || raw
    when String then error
    else parsed[:message] || raw
    end
  end

  # Headers go on the request, never on the connection, which may be shared
  # across fibers and keeps whatever headers the caller configured on it.
  # Faraday matches header names case-insensitively, so a caller's header
  # replaces the subclass's whatever its casing. The content and encoding
  # headers below are always riffer's: the body and the stream depend on them.
  #--
  #: (String, Hash[Symbol, untyped], ?on_data: Proc?) -> Faraday::Response
  def request(path, body, on_data: nil)
    @connection.post(url_for(path)) do |req|
      req.headers.update(@extra_headers)
      headers.each { |name, value| req.headers[name] ||= value }
      req.headers["content-type"] = "application/json"
      if on_data
        req.headers["accept"] = "text/event-stream"
        # Net::HTTP buffers a gzip body until EOF, which stalls the stream.
        req.headers["accept-encoding"] = "identity"
        req.options.on_data = on_data
      end
      req.body = body.to_json
    end
  end

  #--
  #: (Integer, String, String?) -> bot
  def raise_api_error!(status, raw, request_id)
    parsed = begin
      JSON.parse(raw, symbolize_names: true)
    rescue JSON::ParserError
      nil
    end
    # Vertex AI wraps its error object in a one-element array.
    parsed = parsed.first if parsed.is_a?(Array) && parsed.length == 1
    fields = parsed.is_a?(Hash) ? parsed : {} #: Hash[Symbol, untyped]

    message = "#{error_label} API error (#{status}): #{error_message(fields, raw)}"
    raise Riffer::APIError.new(message, status: status, body: raw, request_id: request_id)
  end
end
