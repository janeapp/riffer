# frozen_string_literal: true
# rbs_inline: enabled

# OTEL-backed metrics backend. <tt>::OpenTelemetry</tt> constants appear only
# inside method bodies here, so the gem loads and eager-loads cleanly when the
# OpenTelemetry metrics API is absent.
class Riffer::Metrics::Otel # :nodoc: all
  SUPPORTED_API_VERSIONS = Gem::Requirement.new(">= 0.2", "< 1.0") #: Gem::Requirement

  class << self
    # Builds a backend when the OpenTelemetry metrics API is loadable at a
    # supported version; returns +nil+ so resolution falls back to Null.
    # +provider+ defaults to the global <tt>OpenTelemetry.meter_provider</tt>.
    #--
    #: (?provider: untyped) -> Riffer::Metrics::Otel?
    def build(provider: nil)
      version = api_version
      return nil unless version

      unless supported?(version)
        Kernel.warn "riffer: opentelemetry-metrics-api #{version} is outside the supported range (#{SUPPORTED_API_VERSIONS}); metrics are disabled"
        return nil
      end

      new(provider: provider || ::OpenTelemetry.meter_provider)
    end

    # Whether the OpenTelemetry metrics API gem is loadable at a supported
    # version.
    #--
    #: () -> bool
    def available?
      version = api_version
      !version.nil? && supported?(version)
    end

    # Whether the given opentelemetry-metrics-api version is one riffer codes
    # against. The gem is undeclared, so this guard is the only protection
    # against an incompatible, still-pre-1.0 API.
    #--
    #: (Gem::Version) -> bool
    def supported?(version)
      SUPPORTED_API_VERSIONS.satisfied_by?(version)
    end

    private

    #--
    #: () -> Gem::Version?
    def api_version
      require "opentelemetry-metrics-api"
      spec = Gem.loaded_specs["opentelemetry-metrics-api"] #: untyped
      spec&.version
    rescue ::LoadError
      nil
    end
  end

  # @rbs @meter: untyped
  # @rbs @instruments: Hash[String, untyped]
  # @rbs @mutex: Mutex

  #--
  #: (provider: untyped) -> void
  def initialize(provider:)
    @meter = provider.meter("riffer", version: Riffer::VERSION)
    @instruments = {}
    @mutex = Mutex.new
  end

  # Records a value onto the named histogram.
  #--
  #: (String, Numeric, unit: String?, description: String?, attributes: Hash[String, untyped]?) -> void
  def record_histogram(name, value, unit:, description:, attributes:)
    histogram = @mutex.synchronize do
      @instruments[name] ||= @meter.create_histogram(name, unit: unit, description: description)
    end
    histogram.record(value, attributes: attributes)
  end
end
