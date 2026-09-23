# frozen_string_literal: true
# rbs_inline: enabled

require "base64"
require "uri"

class Riffer::Messages::User::FilePart
  # @rbs @url_string: String?
  # @rbs @data: String?
  # @rbs @downloaded_data: String?
  # @rbs @data_bytes: String?

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

  attr_reader :media_type #: String # @dynamic media_type

  attr_reader :filename #: String? # @dynamic filename

  attr_reader :sha256 #: String? # @dynamic sha256

  # Raises Riffer::ArgumentError on an unsupported +media_type+.
  #--
  #: (media_type: String, ?data: String?, ?filename: String?, ?url: String?, ?sha256: String?) -> void
  def initialize(media_type:, data: nil, filename: nil, url: nil, sha256: nil)
    raise Riffer::ArgumentError, "Either data or url must be provided" if data.nil? && url.nil?
    unless SUPPORTED_MEDIA_TYPES.include?(media_type)
      raise Riffer::ArgumentError,
            "Unsupported media type: #{media_type}"
    end
    unless sha256.nil? || (sha256.is_a?(String) && sha256.match?(SHA256_PATTERN))
      raise Riffer::ArgumentError,
            "Invalid sha256: #{sha256}"
    end

    @sha256 = sha256&.downcase
    @data = data
    @media_type = media_type
    @filename = filename
    @url_string = url
  end

  # Raises Riffer::ArgumentError when +media_type+ is omitted and the URL's
  # extension doesn't identify one.
  #--
  #: (String, ?media_type: String?, ?filename: String?, ?sha256: String?) -> Riffer::Messages::User::FilePart
  def self.from_url(url, media_type: nil, filename: nil, sha256: nil)
    new(url: url, media_type: media_type || detect_media_type(url), filename: filename, sha256: sha256)
  end

  #--
  #: ((Hash[Symbol, untyped] | Riffer::Messages::User::FilePart)) -> Riffer::Messages::User::FilePart
  def self.from_hash(file)
    return file if file.is_a?(Riffer::Messages::User::FilePart)

    url = file[:url]
    data = file[:data]
    media_type = file[:media_type]
    filename = file[:filename]
    sha256 = file[:sha256]

    if url
      new(url: url, data: data, media_type: media_type || detect_media_type(url), filename: filename, sha256: sha256)
    elsif data && media_type
      new(data: data, media_type: media_type, filename: filename, sha256: sha256)
    else
      raise Riffer::ArgumentError, "File hash must include :url or :data with :media_type"
    end
  end

  #--
  #: (String) -> String
  def self.detect_media_type(url)
    ext = ::File.extname(URI.parse(url).path.to_s).downcase
    MEDIA_TYPES.fetch(ext) { raise Riffer::ArgumentError, "Cannot detect media type from URL; provide media_type explicitly" }
  end
  private_class_method :detect_media_type

  #--
  #: () -> String?
  def data
    @data || @downloaded_data
  end

  #: () -> String?
  def data_bytes
    return @data_bytes if @data_bytes

    encoded = data
    return nil unless encoded

    @data_bytes = Base64.strict_decode64(encoded.gsub(/\s/, ""))
  rescue ArgumentError
    raise Riffer::FileEncodingError, "Invalid base64 data"
  end

  #: (String) -> void
  def cache_data_bytes(bytes)
    @data_bytes = bytes
  end

  #: () -> bool
  def inline_data?
    !@data.nil?
  end

  #--
  #: (String) -> void
  def cache_downloaded_data(data)
    @downloaded_data = data
  end

  #--
  #: () -> String?
  def url
    @url_string
  end

  #--
  #: () -> bool
  def url?
    !@url_string.nil?
  end

  #--
  #: () -> bool
  def image?
    media_type.start_with?("image/")
  end

  #--
  #: () -> bool
  def document?
    !image?
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { media_type: media_type } #: Hash[Symbol, untyped]
    # Downloaded data is left out so persisted history stays free of megabytes
    # of base64; the in-memory cache still spares refetching on every turn.
    hash[:data] = @data if @data
    hash[:url] = @url_string if @url_string
    hash[:filename] = filename if filename
    hash[:sha256] = sha256 if sha256
    hash
  end
end
