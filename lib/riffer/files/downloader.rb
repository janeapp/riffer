# frozen_string_literal: true
# rbs_inline: enabled

require "digest"
require "net/http"
require "uri"

class Riffer::Files::Downloader
  MAX_REDIRECTS = 3 #: Integer

  # A String is the URL alone, as passed under the deprecated url-only contract;
  # it skips the sha256 check because riffer still runs it for that contract.
  #--
  #: ((Riffer::Messages::User::FilePart | String), max_bytes: Integer, timeout: Integer) -> String
  def call(file, max_bytes:, timeout:)
    url, sha256 = file.is_a?(String) ? [file, nil] : [file.url, file.sha256]
    raise Riffer::FileDownloadError, "File has no URL to download" if url.nil?

    fetch(url, sha256: sha256, max_bytes: max_bytes, timeout: timeout, redirects_remaining: MAX_REDIRECTS)
  rescue Riffer::Error
    raise
  rescue StandardError => e
    raise Riffer::FileDownloadError, "Error downloading file: #{e.message}"
  end

  private

  #--
  #: (String, sha256: String?, max_bytes: Integer, timeout: Integer, redirects_remaining: Integer) -> String
  def fetch(url, sha256:, max_bytes:, timeout:, redirects_remaining:)
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

    # request_get without a block reads the whole body before returning, so the
    # size cap has to run inside the block, before the body is consumed.
    redirect_location = nil #: String?
    content = nil #: String?

    http.start do
      http.request_get(uri.request_uri) do |response|
        case response
        when Net::HTTPRedirection
          raise Riffer::FileDownloadError, "Too many redirects" if redirects_remaining.zero?

          location = response["location"]
          raise Riffer::FileDownloadError, "Redirect missing Location header" if location.nil?

          redirect_location = URI.join(url, location).to_s
        when Net::HTTPSuccess
          content = read_capped(response, sha256: sha256, max_bytes: max_bytes)
        else
          raise Riffer::FileDownloadError, "File download failed, status: #{response.code}"
        end
      end
    end

    if redirect_location
      return fetch(redirect_location, sha256: sha256, max_bytes: max_bytes, timeout: timeout,
                                      redirects_remaining: redirects_remaining - 1,)
    end

    content #: String
  end

  #--
  #: (Net::HTTPResponse, sha256: String?, max_bytes: Integer) -> String
  def read_capped(response, sha256:, max_bytes:)
    content_length = response["content-length"]&.to_i
    raise Riffer::FileTooLargeError, "File too large" if content_length && content_length > max_bytes

    # Hashing each chunk as it arrives spares a second full pass over the body.
    digest = Digest::SHA256.new if sha256
    buffer = +""
    response.read_body do |chunk|
      buffer << chunk
      raise Riffer::FileTooLargeError, "File too large" if buffer.bytesize > max_bytes

      digest&.update(chunk)
    end
    raise Riffer::FileChecksumMismatchError, "File checksum mismatch" if digest && digest.hexdigest != sha256

    buffer
  end
end
