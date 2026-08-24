# frozen_string_literal: true
# rbs_inline: enabled

require "digest"
require "base64"

class Riffer::Files::Resolver
  # @rbs @provider: Riffer::Providers::Base
  # @rbs @config: Riffer::Config::Files

  #: (provider: Riffer::Providers::Base) -> void
  def initialize(provider:)
    @provider = provider
    @config = Riffer.config.files
  end

  # Resolves every file in every User message in place - downloading,
  # verifying, and caching as the provider's capability and each file's
  # sha256 require.  Raises Riffer::FileError on any file that can't be
  # resolved
  #: (Array[Riffer::Messages::Base]) -> void
  def resolve!(messages)
    files = messages.flat_map do |message|
      next [] unless message.is_a?(Riffer::Messages::User)

      check_file_count!(message)
      message.files
    end

    @config.runner.map(files, context: nil) { |file| resolve_file!(file) }
  end

  private

  #: (Riffer::Messages::User) -> void
  def check_file_count!(message)
    max = @config.max_per_message
    return if max.nil? || message.files.size <= max

    raise Riffer::TooManyFilesError, "Too many files specified in user message"
  end

  #: (Riffer::Messages::FilePart) -> void
  def resolve_file!(file)
    delivery = @provider.file_delivery(file)
    if delivery == :unsupported
      raise Riffer::FileUnsupportedError,
            "Provider does not support user message file attachments"
    end
    return verify_inline!(file) if file.inline_data?

    case delivery
    when :url
      download!(file, cache: false) if file.sha256
    when :data
      file.data ? verify_inline!(file) : download!(file, cache: true)
    else
      raise Riffer::ArgumentError,
            "Unknown file_delivery result #{delivery.inspect} from #{@provider.class}"
    end
  end

  #: (Riffer::Messages::FilePart) -> void
  def verify_inline!(file)
    return unless file.sha256

    verify_bytes!(file.data_bytes, file.sha256)
  end

  # +cache:+ is false for a :url-delivery provider verifying a sha256 — the
  # request still sends the URL, never the downloaded bytes, so caching them
  # would hold memory nothing reads and let later turns skip re-verifying.
  #: (Riffer::Messages::FilePart, cache: bool) -> void
  def download!(file, cache:)
    raise Riffer::FileDownloadsDisabledError, "File attachments are disabled" unless @config.allow_downloads

    raw = @config.downloader.call(file.url, max_bytes: @config.max_bytes, timeout: @config.timeout)
    verify_bytes!(raw, file.sha256) if file.sha256
    return unless cache

    file.cache_downloaded_data(Base64.strict_encode64(raw))
    file.cache_data_bytes(raw)
  end

  def verify_bytes!(bytes, sha256)
    return if Digest::SHA256.hexdigest(bytes) == sha256

    raise Riffer::FileChecksumMismatchError, "File checksum mismatch"
  end
end
