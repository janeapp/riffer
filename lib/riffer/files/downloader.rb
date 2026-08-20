# frozen_string_literal: true
# rbs_inline: enabled

require "net/http"
require "uri"
require "base64"

class Riffer::Files::Downloader
  MAX_REDIRECTS = 3 #: Integer

  #: (String, max_bytes: Integer, timeout: Integer) -> String
  def call(url, max_bytes:, timeout:)
    Base64.strict_encode64(fetch(url, max_bytes: max_bytes, timeout: timeout, redirects_remaining: MAX_REDIRECTS))
  rescue Riffer::Error
    raise
  rescue => e
    raise Riffer::FileDownloadError, "Error downloading file: #{e.message}"
  end

  private

  #: (String, max_bytes: Integer, timeout: Integer, redirects_remaining: Integer) -> String
  def fetch(url, max_bytes:, timeout:, redirects_remaining:)
    uri = begin
      URI.parse(url) #: URI::HTTPS
    rescue URI::InvalidURIError => e
      raise Riffer::FileDownloadError, "Invalid file URL: #{e.message}"
    end
    raise Riffer::FileDownloadError, "Invalid file URL: missing host" if uri.host.nil?
    raise Riffer::FileDownloadError, "Unsupported URL scheme: #{uri.scheme}" unless uri.scheme == "https"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = timeout
    http.read_timeout = timeout

    response = http.start { http.request_get(uri.request_uri) }
    case response
    when Net::HTTPRedirection
      raise Riffer::FileDownloadError, "Too many redirects" if redirects_remaining.zero?
      location = response["location"]
      raise Riffer::FileDownloadError, "Redirect missing Location header" if location.nil?
      fetch(location, max_bytes: max_bytes, timeout: timeout, redirects_remaining: redirects_remaining - 1)
    when Net::HTTPSuccess
      read_capped(response, max_bytes: max_bytes)
    else
      raise Riffer::FileDownloadError, "File download failed, status: #{response.code}"
    end
  end

  #: (Net::HTTPResponse, max_bytes: Integer) -> String
  def read_capped(response, max_bytes:)
    content_length = response["content-length"]&.to_i
    raise Riffer::FileTooLargeError, "File too large" if content_length && content_length > max_bytes

    buffer = +""
    response.read_body do |chunk|
      buffer << chunk
      raise Riffer::FileTooLargeError, "File too large" if buffer.bytesize > max_bytes
    end
    buffer
  end
end
