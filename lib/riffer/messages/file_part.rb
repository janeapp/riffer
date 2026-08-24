# frozen_string_literal: true
# rbs_inline: enabled

require "base64"
require "uri"

# Represents a file attachment (image or document) — from a URL (+from_url+) or
# raw base64 data (+new+).
class Riffer::Messages::FilePart
  # @rbs @url_string: String?
  # @rbs @data: String?
  # @rbs @downloaded_data: String?

  MEDIA_TYPES = {
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".gif" => "image/gif",
    ".webp" => "image/webp",
    ".pdf" => "application/pdf",
    ".txt" => "text/plain",
    ".md" => "text/plain",
    ".csv" => "text/csv",
    ".html" => "text/html",
  }.freeze #: Hash[String, String]

  SUPPORTED_MEDIA_TYPES = MEDIA_TYPES.values.uniq.freeze #: Array[String]
  SHA256_PATTERN = /\A[0-9a-f]{64}\z/i #: Regexp

  # The MIME type of the file.
  attr_reader :media_type #: String

  # The filename, if available.
  attr_reader :filename #: String?

  # The expected SHA-256 of the file contents, if the caller supplied one.
  attr_reader :sha256 #: String?

  # Raises Riffer::ArgumentError unless +data+ or +url+ is given and
  # +media_type+ is supported.
  #--
  #: (media_type: String, ?data: String?, ?filename: String?, ?url: String?, ?sha256: String?) -> void
  def initialize(media_type:, data: nil, filename: nil, url: nil, sha256: nil)
    raise Riffer::ArgumentError, "Either data or url must be provided" if data.nil? && url.nil?
    unless SUPPORTED_MEDIA_TYPES.include?(media_type)
      raise Riffer::ArgumentError,
            "Unsupported media type: #{media_type}"
    end
    raise Riffer::ArgumentError, "Invalid sha256: #{sha256}" unless sha256.nil? || sha256.match?(SHA256_PATTERN)

    @sha256 = sha256&.downcase
    @data = data
    @media_type = media_type
    @filename = filename
    @url_string = url
  end

  # Creates a FilePart from a URL, detecting +media_type+ from the path
  # extension when omitted. Raises Riffer::ArgumentError if it can't be detected.
  #--
  #: (String, ?media_type: String?, ?filename: String?, ?sha256: String?) -> Riffer::Messages::FilePart
  def self.from_url(url, media_type: nil, filename: nil, sha256: nil)
    unless media_type
      ext = ::File.extname(URI.parse(url).path.to_s).downcase
      media_type = MEDIA_TYPES[ext]
      raise Riffer::ArgumentError, "Cannot detect media type from URL; provide media_type explicitly" unless media_type
    end

    new(url: url, media_type: media_type, filename: filename, sha256: sha256)
  end

  # Builds a FilePart from a +{url:, media_type:}+ or +{data:, media_type:}+ hash,
  # or returns +file+ unchanged when it is already a FilePart. Raises
  # Riffer::ArgumentError on an invalid hash.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::FilePart)) -> Riffer::Messages::FilePart
  def self.from_hash(file)
    return file if file.is_a?(Riffer::Messages::FilePart)

    raise Riffer::ArgumentError, "File must be a Hash or FilePart object, got #{file.class}" unless file.is_a?(Hash)

    url = file[:url]
    data = file[:data]
    media_type = file[:media_type]
    filename = file[:filename]
    sha256 = file[:sha256]

    if url
      from_url(url, media_type: media_type, filename: filename, sha256: sha256)
    elsif data && media_type
      new(data: data, media_type: media_type, filename: filename, sha256: sha256)
    else
      raise Riffer::ArgumentError, "File hash must include :url or :data with :media_type"
    end
  end

  # The base64-encoded contents - caller-supplied, or filled in by the file
  # resolver after a download.  Nil for a URL source riffer hasn't fetched.
  #--
  #: () -> String?
  def data
    @data || @downloaded_data
  end

  # Caches bytes fetched for a URL source.  Deliberately absent from +to_h+:
  # the agent loop re-sends history on every turn, so the cache saves refreshing
  # the same file, while persisted history stays free of megabytes of base64
  #--
  #: (String) -> void
  def cache_downloaded_data(data)
    @downloaded_data = data
  end

  # Returns the URL if the source was a URL, nil otherwise.
  #
  #--
  #: () -> String?
  def url
    @url_string
  end

  # Returns true if the source was a URL.
  #
  #--
  #: () -> bool
  def url?
    !@url_string.nil?
  end

  # Returns true if the file is an image.
  #
  #--
  #: () -> bool
  def image?
    media_type.start_with?("image/")
  end

  # Returns true if the file is a document (not an image).
  #
  #--
  #: () -> bool
  def document?
    !image?
  end

  # Serializes the FilePart to a hash.
  #
  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { media_type: media_type } #: Hash[Symbol, untyped]
    hash[:data] = @data if @data
    hash[:url] = @url_string if @url_string
    hash[:filename] = filename if filename
    hash[:sha256] = sha256 if sha256
    hash
  end
end
