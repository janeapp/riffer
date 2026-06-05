# frozen_string_literal: true
# rbs_inline: enabled

require "base64"
require "uri"

# Represents a file attachment (image or document) — from a URL (+from_url+) or
# raw base64 data (+new+).
class Riffer::Messages::FilePart
  # @rbs @url_string: String?

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

  # Raises Riffer::ArgumentError unless +data+ or +url+ is given and
  # +media_type+ is supported.
  #--
  #: (media_type: String, ?data: String?, ?filename: String?, ?url: String?) -> void
  def initialize(media_type:, data: nil, filename: nil, url: nil)
    raise Riffer::ArgumentError, "Either data or url must be provided" if data.nil? && url.nil?
    raise Riffer::ArgumentError, "Unsupported media type: #{media_type}" unless SUPPORTED_MEDIA_TYPES.include?(media_type)

    @data = data
    @media_type = media_type
    @filename = filename
    @url_string = url
  end

  # Creates a FilePart from a URL, detecting +media_type+ from the path
  # extension when omitted. Raises Riffer::ArgumentError if it can't be detected.
  #--
  #: (String, ?media_type: String?) -> Riffer::Messages::FilePart
  def self.from_url(url, media_type: nil)
    unless media_type
      ext = ::File.extname(URI.parse(url).path.to_s).downcase
      media_type = MEDIA_TYPES[ext]
      raise Riffer::ArgumentError, "Cannot detect media type from URL; provide media_type explicitly" unless media_type
    end

    new(url: url, media_type: media_type)
  end

  # Builds a FilePart from a +{url:, media_type:}+ or +{data:, media_type:}+ hash,
  # or returns +file+ unchanged when it is already a FilePart. Raises
  # Riffer::ArgumentError on an invalid hash.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::FilePart)) -> Riffer::Messages::FilePart
  def self.from_hash(file)
    return file if file.is_a?(Riffer::Messages::FilePart)

    unless file.is_a?(Hash)
      raise Riffer::ArgumentError, "File must be a Hash or FilePart object, got #{file.class}"
    end

    url = file[:url]
    data = file[:data]
    media_type = file[:media_type]
    filename = file[:filename]

    if url
      from_url(url, media_type: media_type)
    elsif data && media_type
      new(data: data, media_type: media_type, filename: filename)
    else
      raise Riffer::ArgumentError, "File hash must include :url or :data with :media_type"
    end
  end

  # Returns the base64-encoded data, or nil for URL-only sources.
  attr_reader :data #: String?

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
    hash = {media_type: media_type} #: Hash[Symbol, untyped]
    hash[:data] = @data if @data
    hash[:url] = @url_string if @url_string
    hash[:filename] = filename if filename
    hash
  end
end
