# frozen_string_literal: true
# rbs_inline: enabled

require "digest"
require "base64"

class Riffer::Files::Resolver
  # @rbs @provider: Riffer::Providers::Base
  # @rbs @config: Riffer::Config::Files
  # @rbs @file_downloads: bool

  DEPRECATIONS = {
    url_downloader: "Calling config.files.downloader with the file's URL is deprecated; a future breaking release " \
                    "calls it with the Riffer::Messages::User::FilePart and expects it to check file.sha256. " \
                    "Update the downloader and set config.future.file_downloads = true.",
    url_sha256_check: "Downloading a file the provider fetches by URL, only to check its sha256, is deprecated; " \
                      "a future breaking release passes the URL through unchecked. " \
                      "Set config.future.file_downloads = true to opt in now.",
  }.freeze #: Hash[Symbol, String]

  #: (provider: Riffer::Providers::Base) -> void
  def initialize(provider:)
    @provider = provider
    @config = Riffer.config.files
    @file_downloads = Riffer.config.future.enabled?(:file_downloads)
  end

  #: (Array[Riffer::Messages::Base]) -> void
  def resolve!(messages)
    files = messages.flat_map do |message|
      next [] unless message.is_a?(Riffer::Messages::User)

      check_file_count!(message)
      message.files
    end

    deprecations = @config.runner.map(files.uniq, context: nil) { |file| resolve_file!(file) }
    # Reported here rather than inside the runner, whose threads and fibers
    # carry no caller frames to name the app's line.
    deprecations.flatten.each { |id| Riffer::Deprecation.warn(id: id, message: DEPRECATIONS.fetch(id)) }
  end

  private

  #: (Riffer::Messages::User) -> void
  def check_file_count!(message)
    max = @config.max_per_message
    return if max.nil? || message.files.size <= max

    raise Riffer::TooManyFilesError, "Too many files specified in user message"
  end

  #--
  #: (Riffer::Messages::User::FilePart) -> Array[Symbol]
  def resolve_file!(file)
    delivery = @provider.file_delivery(file)
    if delivery == :unsupported
      raise Riffer::FileUnsupportedError,
            "Provider does not support user message file attachments"
    end
    if file.inline_data?
      verify_inline!(file, delivery)
      return []
    end

    case delivery
    when :url then check_url!(file)
    when :base64, :bytes then download_unless_cached!(file, delivery)
    else
      raise Riffer::ArgumentError,
            "Unknown file_delivery result #{delivery.inspect} from #{@provider.class}"
    end
  end

  #--
  #: (Riffer::Messages::User::FilePart) -> Array[Symbol]
  def check_url!(file)
    return [] if file.sha256.nil? || file.verified? || @file_downloads

    # The request sends the URL, never these bytes, so caching them would
    # hold memory nothing reads.
    [:url_sha256_check, *download!(file, cache: false)]
  end

  #--
  #: (Riffer::Messages::User::FilePart, Symbol) -> Array[Symbol]
  def download_unless_cached!(file, delivery)
    cached = delivery == :base64 ? file.data : file.data_bytes
    cached ? [] : download!(file, cache: delivery)
  end

  #--
  #: (Riffer::Messages::User::FilePart, Symbol) -> void
  def verify_inline!(file, delivery)
    sha256 = file.sha256
    return if sha256.nil? || file.verified?

    # Only a :bytes provider sends the decoded content, so only it keeps a copy.
    bytes = (delivery == :bytes ? file.data_bytes : file.decoded_data) #: String
    verify_bytes!(bytes, sha256)
    file.mark_verified
  end

  #--
  #: (Riffer::Messages::User::FilePart, cache: (false | Symbol)) -> Array[Symbol]
  def download!(file, cache:)
    raise Riffer::FileDownloadsDisabledError, "File attachments are disabled" unless @config.allow_downloads

    url_downloader = url_downloader?
    raw = url_downloader ? download_by_url(file) : download_file(file)
    file.mark_verified if file.sha256

    case cache
    when :base64
      file.cache_downloaded_data(Base64.strict_encode64(raw))
    when :bytes
      file.cache_data_bytes(raw)
    end
    url_downloader ? [:url_downloader] : []
  end

  #--
  #: () -> bool
  def url_downloader?
    !@file_downloads && !@config.downloader.instance_of?(Riffer::Files::Downloader)
  end

  # The downloader's own errors propagate unwrapped so a host can raise and
  # rescue its own error classes.
  #--
  #: (Riffer::Messages::User::FilePart) -> String
  def download_file(file)
    @config.downloader.call(file, max_bytes: @config.max_bytes, timeout: @config.timeout)
  end

  #--
  #: (Riffer::Messages::User::FilePart) -> String
  def download_by_url(file)
    url = file.url #: String
    raw = @config.downloader.call(url, max_bytes: @config.max_bytes, timeout: @config.timeout)
    sha256 = file.sha256
    verify_bytes!(raw, sha256) if sha256
    raw
  end

  #--
  #: (String, String) -> void
  def verify_bytes!(bytes, sha256)
    return if Digest::SHA256.hexdigest(bytes) == sha256

    raise Riffer::FileChecksumMismatchError, "File checksum mismatch"
  end
end
