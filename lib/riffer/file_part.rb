# frozen_string_literal: true
# rbs_inline: enabled

require "base64"
require "uri"

# Represents a file attachment (image or document) in a conversation.
#
# Supports two input sources:
# - URLs (stored and passed to providers that support them via +from_url+)
# - Raw base64 data (via +new+)
#
#   file = Riffer::FilePart.from_url("https://example.com/doc.pdf", media_type: "application/pdf")
#   file.url?        # => true
#   file.document?   # => true
#
class Riffer::FilePart
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
    ".html" => "text/html"
  }.freeze #: Hash[String, String]

  SUPPORTED_MEDIA_TYPES = MEDIA_TYPES.values.uniq.freeze #: Array[String]

  # The MIME type of the file.
  attr_reader :media_type #: String

  # The filename, if available.
  attr_reader :filename #: String?

  # Creates a FilePart from raw base64 data or a URL.
  #
  # At least one of +data+ or +url+ must be provided.
  #
  # Raises Riffer::ArgumentError if neither data nor url is provided,
  # or if media_type is not supported.
  #
  #: (media_type: String, ?data: String?, ?filename: String?, ?url: String?) -> void
  def initialize(media_type:, data: nil, filename: nil, url: nil)
    raise Riffer::ArgumentError, "Either data or url must be provided" if data.nil? && url.nil?
    raise Riffer::ArgumentError, "Unsupported media type: #{media_type}" unless SUPPORTED_MEDIA_TYPES.include?(media_type)

    @data = data
    @media_type = media_type
    @filename = filename
    @url_string = url
  end

  # Creates a FilePart from a URL.
  #
  # The URL is stored and passed directly to providers that support URL sources.
  # If +media_type+ is not provided, it is detected from the URL path extension.
  #
  # Raises Riffer::ArgumentError if media_type cannot be detected.
  #
  #: (String, ?media_type: String?) -> Riffer::FilePart
  def self.from_url(url, media_type: nil)
    unless media_type
      ext = ::File.extname(URI.parse(url).path).downcase
      media_type = MEDIA_TYPES[ext]
      raise Riffer::ArgumentError, "Cannot detect media type from URL; provide media_type explicitly" unless media_type
    end

    new(url: url, media_type: media_type)
  end

  # Returns the base64-encoded data, or nil for URL-only sources.
  attr_reader :data #: String?

  # Returns the URL if the source was a URL, nil otherwise.
  #
  #: () -> String?
  def url
    @url_string
  end

  # Returns true if the source was a URL.
  #
  #: () -> bool
  def url?
    !@url_string.nil?
  end

  # Returns true if the file is an image.
  #
  #: () -> bool
  def image?
    media_type.start_with?("image/")
  end

  # Returns true if the file is a document (not an image).
  #
  #: () -> bool
  def document?
    !image?
  end

  # Serializes the FilePart to a hash.
  #
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {media_type: media_type}
    hash[:data] = @data if @data
    hash[:url] = @url_string if @url_string
    hash[:filename] = filename if filename
    hash
  end
end
