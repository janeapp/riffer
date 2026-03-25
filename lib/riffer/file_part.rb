# frozen_string_literal: true
# rbs_inline: enabled

require "base64"
require "uri"

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

  attr_reader :media_type #: String

  attr_reader :filename #: String?

  #: (media_type: String, ?data: String?, ?filename: String?, ?url: String?) -> void
  def initialize(media_type:, data: nil, filename: nil, url: nil)
    raise Riffer::ArgumentError, "Either data or url must be provided" if data.nil? && url.nil?
    raise Riffer::ArgumentError, "Unsupported media type: #{media_type}" unless SUPPORTED_MEDIA_TYPES.include?(media_type)

    @data = data
    @media_type = media_type
    @filename = filename
    @url_string = url
  end

  #: (String, ?media_type: String?) -> Riffer::FilePart
  def self.from_url(url, media_type: nil)
    unless media_type
      ext = ::File.extname(URI.parse(url).path).downcase
      media_type = MEDIA_TYPES[ext]
      raise Riffer::ArgumentError, "Cannot detect media type from URL; provide media_type explicitly" unless media_type
    end

    new(url: url, media_type: media_type)
  end

  attr_reader :data #: String?

  #: () -> String?
  def url
    @url_string
  end

  #: () -> bool
  def url?
    !@url_string.nil?
  end

  #: () -> bool
  def image?
    media_type.start_with?("image/")
  end

  #: () -> bool
  def document?
    !image?
  end

  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = {media_type: media_type}
    hash[:data] = @data if @data
    hash[:url] = @url_string if @url_string
    hash[:filename] = filename if filename
    hash
  end
end
