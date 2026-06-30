# frozen_string_literal: true
# rbs_inline: enabled

# OTEL-backed tracing backend. <tt>::OpenTelemetry</tt> constants appear only
# inside method bodies here, so the gem loads and eager-loads cleanly when the
# OpenTelemetry API is absent.
class Riffer::Tracing::Otel # :nodoc: all
  SUPPORTED_API_VERSIONS = Gem::Requirement.new(">= 1.1", "< 2") #: Gem::Requirement

  # Wraps a live OTEL span behind the port's span surface, so callers never
  # touch <tt>::OpenTelemetry</tt> constants (status objects in particular).
  class Span
    # @rbs @otel_span: untyped

    #--
    #: (untyped) -> void
    def initialize(otel_span)
      @otel_span = otel_span
    end

    #--
    #: (String, untyped) -> void
    def set_attribute(key, value)
      @otel_span.set_attribute(key, value)
    end

    #--
    #: (String, ?attributes: Hash[String, untyped]?) -> void
    def add_event(name, attributes: nil)
      @otel_span.add_event(name, attributes: attributes)
    end

    #--
    #: (Exception) -> void
    def record_exception(exception)
      @otel_span.record_exception(exception)
    end

    # Marks the span status as error.
    #--
    #: (?String) -> void
    def error!(description = "")
      @otel_span.status = ::OpenTelemetry::Trace::Status.error(description)
    end

    #--
    #: () -> bool
    def recording?
      @otel_span.recording?
    end
  end

  class << self
    # Builds a backend when the OpenTelemetry API is loadable at a supported
    # version; returns +nil+ so resolution falls back to NoOp. +provider+
    # defaults to the global <tt>OpenTelemetry.tracer_provider</tt>.
    #--
    #: (?provider: untyped) -> Riffer::Tracing::Otel?
    def build(provider: nil)
      version = api_version
      return nil unless version

      unless supported?(version)
        Kernel.warn "riffer: opentelemetry-api #{version} is outside the supported range (#{SUPPORTED_API_VERSIONS}); tracing is disabled"
        return nil
      end

      new(provider: provider || ::OpenTelemetry.tracer_provider)
    end

    # Whether the OpenTelemetry API gem is loadable at a supported version.
    #--
    #: () -> bool
    def available?
      version = api_version
      !version.nil? && supported?(version)
    end

    # Whether the given opentelemetry-api version is one riffer codes
    # against. The gem is undeclared, so this guard is the only protection
    # against an incompatible API.
    #--
    #: (Gem::Version) -> bool
    def supported?(version)
      SUPPORTED_API_VERSIONS.satisfied_by?(version)
    end

    private

    #--
    #: () -> Gem::Version?
    def api_version
      require "opentelemetry"
      spec = Gem.loaded_specs["opentelemetry-api"] #: untyped
      spec&.version
    rescue ::LoadError
      nil
    end
  end

  # @rbs @tracer: untyped

  #--
  #: (provider: untyped) -> void
  def initialize(provider:)
    @tracer = provider.tracer("riffer", Riffer::VERSION)
  end

  # Opens an OTEL span around the block, yielding the wrapped span.
  #--
  #: [R] (String, attributes: Hash[String, untyped]?, kind: Symbol) { (Riffer::Tracing::Otel::Span) -> R } -> R
  def in_span(name, attributes:, kind:)
    @tracer.in_span(name, attributes: attributes, kind: kind) do |otel_span, _context|
      yield Span.new(otel_span)
    end
  end

  # Returns the active OTEL context.
  #--
  #: () -> untyped
  def current_context
    ::OpenTelemetry::Context.current
  end

  # Runs the block with the given OTEL context active.
  #--
  #: [R] (untyped) { () -> R } -> R
  def with_context(context)
    return yield if context.nil?
    ::OpenTelemetry::Context.with_current(context) { yield }
  end

  #--
  #: () -> Hash[Symbol, String?]
  def current_trace_ids
    span_context = ::OpenTelemetry::Trace.current_span.context
    return {trace_id: nil, span_id: nil} unless span_context.valid?
    {trace_id: span_context.hex_trace_id, span_id: span_context.hex_span_id}
  end
end
