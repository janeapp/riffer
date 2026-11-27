# frozen_string_literal: true
# rbs_inline: enabled

require "faraday"
require "uri"

class Riffer::Files::Downloader
  MAX_REDIRECTS = 3 #: Integer

  # Faraday's default encoder sorts the query, drops repeated keys and turns
  # %20 into +, which breaks presigned URLs. This one keeps the query as sent.
  module RawQuery
    #--
    #: (String?) -> Hash[String, nil]
    def self.decode(query)
      query.to_s.empty? ? {} : { query.to_s => nil }
    end

    #--
    #: (Hash[String, untyped]) -> String
    def self.encode(params)
      params.keys.join("&")
    end
  end
  private_constant :RawQuery

  #--
  #: (Array[Riffer::Messages::User::FilePart]) -> Array[String]
  #: (String, max_bytes: Integer, timeout: Integer) -> String
  def call(files, max_bytes: nil, timeout: nil)
    # The resolver's pre-flag path, and custom downloaders on the deprecated
    # call(url, max_bytes:, timeout:) contract that wrap this one, pass a URL.
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

    Faraday.new(request: { params_encoder: RawQuery }).get(uri)
  end
end
