# frozen_string_literal: true
# rbs_inline: enabled

# Internal tracing port — emits OTEL spans when the host bundles the
# OpenTelemetry API and no-ops otherwise, so riffer never declares an OTEL
# dependency.
module Riffer::Tracing # :nodoc: all
  extend self

  # @rbs @backend: (Riffer::Tracing::Otel | singleton(Riffer::Tracing::Null))?

  MUTEX = Mutex.new #: Mutex

  # The Ruby API cannot attach a schema URL to a tracer, so the semconv pin
  # lives here as the documented contract version.
  SCHEMA_URL = "https://opentelemetry.io/schemas/1.37.0" #: String

  # Opens a span around the block, yielding the span.
  #--
  #: [R] (String, ?attributes: Hash[String, untyped]?, ?kind: Symbol) { (Riffer::Tracing::Otel::Span | Riffer::Tracing::Null::Span) -> R } -> R
  def in_span(name, attributes: nil, kind: :internal, &block)
    return Null.in_span(name, &block) unless Riffer.config.tracing.enabled
    backend.in_span(name, attributes: attributes, kind: kind, &block)
  end

  # Returns the active trace context, for re-attachment across fiber or
  # thread boundaries.
  #--
  #: () -> untyped
  def current_context
    return Null.current_context unless Riffer.config.tracing.enabled
    backend.current_context
  end

  # Runs the block with the given trace context active; +nil+ passes through
  # so captures taken while tracing was dark stay harmless.
  #--
  #: [R] (untyped) { () -> R } -> R
  def with_context(context, &block)
    return Null.with_context(context, &block) unless Riffer.config.tracing.enabled
    backend.with_context(context, &block)
  end

  # Discards the resolved backend so the next span re-resolves it.
  #--
  #: () -> void
  def reset!
    MUTEX.synchronize { @backend = nil }
  end

  private

  #--
  #: () -> (Riffer::Tracing::Otel | singleton(Riffer::Tracing::Null))
  def backend
    @backend || MUTEX.synchronize { @backend ||= resolve_backend }
  end

  #--
  #: () -> (Riffer::Tracing::Otel | singleton(Riffer::Tracing::Null))
  def resolve_backend
    Otel.build(provider: Riffer.config.tracing.tracer_provider) || Null
  end
end
