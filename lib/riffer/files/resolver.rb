# frozen_string_literal: true
# rbs_inline: enabled

require "digest"

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
    return verify_inline!(file) if file.data

    case @provider.file_delivery(file)
    when :unsupported
      raise Riffer::FileUnsupportedError, "Provider does not support user message file attachments"
    when :url
      download!(file, cache: false) if file.sha256
    when :data
      download!(file, cache: true)
    end
  end

  #: (Riffer::Messages::FilePart) -> void
  def verify_inline!(file)
    return unless file.sha256

    verify_encoded!(file.data, file.sha256)
  end

  # +cache:+ is false for a :url-delivery provider verifying a sha256 — the
  # request still sends the URL, never the downloaded bytes, so caching them
  # would hold memory nothing reads and let later turns skip re-verifying.
  #: (Riffer::Messages::FilePart, cache: bool) -> void
  def download!(file, cache:)
    raise Riffer::FileDownloadsDisabledError, "File attachments are disabled" unless @config.allow_downloads

    encoded = @config.downloader.call(file.url, max_bytes: @config.max_bytes, timeout: @config.timeout)
    verify_encoded!(encoded, file.sha256) if file.sha256
    file.cache_downloaded_data(encoded) if cache
  end

  def verify_encoded!(encoded, sha256)
    return if Digest::SHA256.hexdigest(Base64.decode64(encoded)) == sha256

    raise Riffer::FileChecksumMismatchError,
          "File checksum mismatch"
  end
end
