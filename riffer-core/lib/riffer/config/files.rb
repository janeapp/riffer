# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Files
  attr_reader :allow_downloads #: bool # @dynamic allow_downloads
  attr_reader :max_bytes #: Integer # @dynamic max_bytes
  attr_reader :timeout #: Integer # @dynamic timeout
  attr_reader :max_per_message #: Integer? # @dynamic max_per_message
  attr_reader :runner #: Riffer::Runner # @dynamic runner
  attr_reader :downloader #: untyped # @dynamic downloader

  #--
  #: () -> void
  def initialize
    @allow_downloads = false
    @max_bytes = 3_500_000
    @timeout = 60
    @max_per_message = nil
    @runner = Riffer::Runner::Sequential.new
    @downloader = Riffer::Files::Downloader.new
  end

  #--
  #: (untyped) -> void
  def allow_downloads=(value)
    @allow_downloads = Riffer::Helpers::Boolean.coerce(value, attribute: "allow_downloads")
  end

  #--
  #: (untyped) -> void
  def max_bytes=(value)
    deprecate_setting(:max_bytes, "set a size limit in a custom downloader")
    @max_bytes = Riffer::Helpers::Validate.positive_integer(value, attribute: "max_bytes")
  end

  #--
  #: (untyped) -> void
  def timeout=(value)
    deprecate_setting(:timeout, "set timeouts in a custom downloader")
    @timeout = Riffer::Helpers::Validate.positive_integer(value, attribute: "timeout")
  end

  #--
  #: (untyped) -> void
  def max_per_message=(value)
    deprecate_setting(:max_per_message, "count files in a :before guardrail")
    @max_per_message =
      value.nil? ? nil : Riffer::Helpers::Validate.positive_integer(value, attribute: "max_per_message")
  end

  #--
  #: (untyped) -> void
  def runner=(value)
    deprecate_setting(:runner, "parallel downloads are up to the downloader")
    @runner = Riffer::Helpers::Validate.runner(value, attribute: "runner")
  end

  #--
  #: (untyped) -> void
  def downloader=(value)
    raise Riffer::ArgumentError, "downloader must respond to #call" unless value.respond_to?(:call)

    @downloader = value
  end

  private

  #--
  #: (Symbol, String) -> void
  def deprecate_setting(name, replacement)
    Riffer::Deprecation.warn(
      id: :"files_#{name}",
      message: "config.files.#{name} is deprecated and will be removed, and config.future.file_downloads " \
               "ignores it; #{replacement}.",
    )
  end
end
