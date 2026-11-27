# frozen_string_literal: true
# rbs_inline: enabled

require "base64"
require "uri"

class Riffer::Messages::User::FilePart
  # @rbs @url_string: String?
  # @rbs @data: String?
  # @rbs @downloaded_data: String?
  # @rbs @data_bytes: String?
  # @rbs @bytes: String?
  # @rbs @encoded_bytes: String?
  # @rbs @verified: bool

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

  # +bytes+ is held, not copied, so a large file isn't duplicated in memory;
  # don't mutate it afterwards: base64 providers encode it once and keep
  # sending that encoding.
  #--
  #: (media_type: String, ?data: String?, ?bytes: String?, ?filename: String?, ?url: String?, ?sha256: String?) -> void
  def initialize(media_type:, data: nil, bytes: nil, filename: nil, url: nil, sha256: nil)
    raise Riffer::ArgumentError, "Either data, bytes or url must be provided" if data.nil? && bytes.nil? && url.nil?
    raise Riffer::ArgumentError, "bytes cannot be combined with data" if data && bytes
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
    @bytes = bytes
    @media_type = media_type
    @filename = filename
    @url_string = url
    @verified = false
  end

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
    bytes = file[:bytes]
    media_type = file[:media_type]
    filename = file[:filename]
    sha256 = file[:sha256]

    if url
      new(url: url, data: data, bytes: bytes, media_type: media_type || detect_media_type(url), filename: filename,
          sha256: sha256,)
    elsif (data || bytes) && media_type
      new(data: data, bytes: bytes, media_type: media_type, filename: filename, sha256: sha256)
    else
      raise Riffer::ArgumentError, "File hash must include :url, or :data or :bytes with :media_type"
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
    bytes = @bytes
    return @encoded_bytes ||= Base64.strict_encode64(bytes) if bytes

    @data || @downloaded_data
  end

  #: () -> String?
  def data_bytes
    return @bytes if @bytes

    @data_bytes ||= decoded_data
  end

  # Unlike +data_bytes+, keeps no decoded copy, for a caller that reads the
  # bytes once while the provider sends the base64.
  #--
  #: () -> String?
  def decoded_data
    raw = @bytes || @data_bytes
    return raw if raw

    encoded = @data || @downloaded_data
    return nil unless encoded

    Base64.strict_decode64(encoded.gsub(/\s/, ""))
  rescue ArgumentError
    raise Riffer::FileEncodingError, "Invalid base64 data"
  end

  #: (String) -> void
  def cache_data_bytes(bytes)
    @data_bytes = bytes
  end

  #: () -> bool
  def inline_data?
    !!(@data || @bytes)
  end

  #--
  #: (String) -> void
  def cache_downloaded_data(data)
    @downloaded_data = data
  end

  # Whether this file's content has been checked against +sha256+. Held in
  # memory only, so a file rebuilt from +to_h+ is checked again.
  #--
  #: () -> bool
  def verified?
    @verified
  end

  #--
  #: () -> void
  def mark_verified
    @verified = true
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
  #: () -> bool
  def text?
    media_type.start_with?("text/")
  end

  # The first extension registered for the media type, e.g. ".jpg" for image/jpeg.
  #--
  #: () -> String
  def extension
    MEDIA_TYPES.key(media_type).to_s
  end

  #--
  #: () -> Hash[Symbol, untyped]
  def to_h
    hash = { media_type: media_type } #: Hash[Symbol, untyped]
    # Downloaded data and +bytes:+ content (raw or encoded) are left out so
    # persisted history stays free of file content; the in-memory copies
    # still spare refetching or re-encoding on every turn.
    hash[:data] = @data if @data
    hash[:url] = @url_string if @url_string
    hash[:filename] = filename if filename
    hash[:sha256] = sha256 if sha256
    hash
  end
end
