# frozen_string_literal: true
# rbs_inline: enabled

require "faraday"
require "uri"

class Riffer::Files::Downloader
  MAX_REDIRECTS = 3 #: Integer

  # A URL comes from a custom downloader on the deprecated
  # call(url, max_bytes:, timeout:) contract that wraps this one.
  #--
  #: (Array[Riffer::Messages::User::FilePart]) -> Array[String]
  #: (String, max_bytes: Integer, timeout: Integer) -> String
  def call(files, max_bytes: nil, timeout: nil)
    if files.is_a?(String)
      size_limit = max_bytes #: Integer
      seconds = timeout #: Integer
      return Riffer::Files::Resolver::LegacyDownloader.new.call(files, max_bytes: size_limit, timeout: seconds)
    end

    files.map { |file| download(file.url.to_s) }
  end

  private

  #--
  #: (String) -> String
  def download(url)
    redirects = 0
    loop do
      response = get(url)
      return response.body.to_s if response.success?

      location = response.headers["location"]
      unless location && response.status.between?(300, 399)
        raise Riffer::FileDownloadError, "File download failed, status: #{response.status}"
      end
      raise Riffer::FileDownloadError, "Too many redirects" if redirects == MAX_REDIRECTS

      redirects += 1
      url = URI.join(url, location).to_s
    end
  rescue Faraday::Error, URI::Error => e
    raise Riffer::FileDownloadError, "Error downloading file: #{e.message}"
  end

  #--
  #: (String) -> Faraday::Response
  def get(url)
    uri = URI.parse(url)
    raise Riffer::FileDownloadError, "Unsupported URL scheme: #{uri.scheme}" unless uri.is_a?(URI::HTTP)
    # Net::HTTP connects to localhost when the host is empty.
    raise Riffer::FileDownloadError, "Invalid file URL: missing host" if uri.host.to_s.empty?

    Faraday.new.get(uri)
  end
end
