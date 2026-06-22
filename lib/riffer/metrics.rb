# frozen_string_literal: true
# rbs_inline: enabled

# Internal metrics port — records OTEL metric instruments when the host bundles
# the OpenTelemetry metrics API and no-ops otherwise, so riffer never declares
# an OTEL dependency.
module Riffer::Metrics # :nodoc: all
  extend self

  # @rbs @backend: untyped

  MUTEX = Mutex.new #: Mutex

  # The Ruby API cannot attach a schema URL to a meter, so the semconv pin
  # lives here as the documented contract version.
  SCHEMA_URL = "https://opentelemetry.io/schemas/1.37.0" #: String

  # A handle to a named histogram, safe to hold as a constant: it defers backend
  # resolution to record time, so it survives a meter-provider swap or a runtime
  # +enabled+ flip.
  class Histogram
    # @rbs @name: String
    # @rbs @unit: String?
    # @rbs @description: String?

    #--
    #: (String, ?unit: String?, ?description: String?) -> void
    def initialize(name, unit: nil, description: nil)
      @name = name
      @unit = unit
      @description = description
    end

    #--
    #: (Numeric, ?attributes: Hash[String, untyped]?) -> void
    def record(value, attributes: nil)
      Riffer::Metrics.record_histogram(@name, value, unit: @unit, description: @description, attributes: attributes)
    end
  end

  # Returns a handle to the named histogram.
  #--
  #: (String, ?unit: String?, ?description: String?) -> Riffer::Metrics::Histogram
  def create_histogram(name, unit: nil, description: nil)
    Histogram.new(name, unit: unit, description: description)
  end

  # Records a value onto the named histogram.
  #--
  #: (String, Numeric, ?unit: String?, ?description: String?, ?attributes: Hash[String, untyped]?) -> void
  def record_histogram(name, value, unit: nil, description: nil, attributes: nil)
    return unless Riffer.config.metrics.enabled
    backend.record_histogram(name, value, unit: unit, description: description, attributes: attributes)
  end

  # Mirrors a span's +recording?+ so a caller can skip work that exists only to
  # feed a metric. True for any live backend — the OTEL backend or a
  # consumer-supplied one — so a custom metrics sink still gets fed.
  #--
  #: () -> bool
  def recording?
    Riffer.config.metrics.enabled && !backend.equal?(NoOp)
  end

  # Reads the monotonic clock in seconds — the time source for duration metrics,
  # immune to wall-clock adjustments.
  #--
  #: () -> Float
  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Discards the resolved backend so the next record re-resolves it; cached
  # instruments live on that backend, so this clears them too.
  #--
  #: () -> void
  def reset!
    MUTEX.synchronize { @backend = nil }
  end

  private

  #--
  #: () -> untyped
  def backend
    @backend || MUTEX.synchronize { @backend ||= resolve_backend }
  end

  #--
  #: () -> untyped
  def resolve_backend
    Riffer.config.metrics.backend || NoOp
  end
end
