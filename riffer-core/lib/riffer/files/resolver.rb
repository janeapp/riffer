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

    raise Riffer::Deprecation.allow { Riffer::TooManyFilesError }, "Too many files specified in user message"
  end

  #: (Riffer::Messages::User::FilePart) -> void
  def resolve_file!(file)
    delivery = @provider.file_delivery(file)
    if delivery == :unsupported
      raise Riffer::FileUnsupportedError,
            "Provider does not support user message file attachments"
    end
    return verify_inline!(file) if file.inline_data?

    case delivery
    when :url
      # The request still sends the URL, never these bytes, so caching them
      # would hold memory nothing reads and let later turns skip re-verifying.
      download!(file, cache: false) if file.sha256
    when :base64
      file.data ? verify_inline!(file) : download!(file, cache: :base64)
    when :bytes
      file.data_bytes ? verify_inline!(file) : download!(file, cache: :bytes)
    else
      raise Riffer::ArgumentError,
            "Unknown file_delivery result #{delivery.inspect} from #{@provider.class}"
    end
  end

  #: (Riffer::Messages::User::FilePart) -> void
  def verify_inline!(file)
    return unless file.sha256

    verify_bytes!(file.data_bytes, file.sha256)
  end

  #: (Riffer::Messages::User::FilePart, cache: (false | Symbol)) -> void
  def download!(file, cache:)
    raise Riffer::FileDownloadsDisabledError, "File attachments are disabled" unless @config.allow_downloads

    raw = downloader.call(file.url, max_bytes: @config.max_bytes, timeout: @config.timeout)
    verify_bytes!(raw, file.sha256) if file.sha256

    case cache
    when :base64
      file.cache_downloaded_data(Base64.strict_encode64(raw))
    when :bytes
      file.cache_data_bytes(raw)
    when false
      nil
    end
  end

  def verify_bytes!(bytes, sha256)
    Riffer::Deprecation.warn(
      id: :files_sha256_check,
      message: "A file's sha256 will no longer be verified; check it in a custom downloader or an " \
               ":after_files_download guardrail (see config.future.file_downloads).",
    )
    return if Digest::SHA256.hexdigest(bytes) == sha256

    raise Riffer::Deprecation.allow { Riffer::FileChecksumMismatchError }, "File checksum mismatch"
  end

  # The built-in downloader is on the call(files) contract, so this path
  # swaps in the old implementation to keep max_bytes, timeout and https-only.
  #--
  #: () -> untyped
  def downloader
    configured = @config.downloader
    return LegacyDownloader.new if configured.instance_of?(Riffer::Files::Downloader)

    Riffer::Deprecation.warn(
      id: :files_downloader_contract,
      message: "A downloader on the call(url, max_bytes:, timeout:) contract is deprecated; under " \
               "config.future.file_downloads riffer calls downloader.call(files) with a batch of FileParts " \
               "and expects their raw bytes back in the same order.",
    )
    configured
  end
end
