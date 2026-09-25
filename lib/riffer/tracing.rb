# frozen_string_literal: true
# rbs_inline: enabled

# No-ops unless the host bundles the OpenTelemetry API, so riffer never
# declares an OTEL dependency.
module Riffer::Tracing # :nodoc: all
  extend self

  # The Ruby API cannot attach a schema URL to a tracer, so the semconv pin
  # lives here as the documented contract version.
  SCHEMA_URL = "https://opentelemetry.io/schemas/1.37.0" #: String

  #--
  #: [R] (String, ?attributes: Hash[String, untyped]?, ?kind: Symbol) { (Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span) -> R } -> R
  def in_span(name, attributes: nil, kind: :internal, &)
    return NoOp.in_span(name, &) unless Riffer.config.tracing.enabled

    backend.in_span(name, attributes: attributes, kind: kind, &)
  end

  # For re-attachment across fiber or thread boundaries.
  #--
  #: () -> untyped
  def current_context
    return NoOp.current_context unless Riffer.config.tracing.enabled

    backend.current_context
  end

  # +nil+ passes through so captures taken while tracing was off stay harmless.
  #--
  #: [R] (untyped) { () -> R } -> R
  def with_context(context, &)
    return NoOp.with_context(context, &) unless Riffer.config.tracing.enabled

    backend.with_context(context, &)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Riffer::Providers::TokenUsage?) -> void
  def record_usage(span, usage)
    return unless usage

    span.set_attribute("gen_ai.usage.input_tokens", usage.input_tokens)
    span.set_attribute("gen_ai.usage.output_tokens", usage.output_tokens)
    span.set_attribute("gen_ai.usage.cache_read.input_tokens", usage.cache_read_tokens) if usage.cache_read_tokens
    span.set_attribute("gen_ai.usage.cache_creation.input_tokens", usage.cache_write_tokens) if usage.cache_write_tokens
    span.set_attribute("riffer.cost", usage.cost) if usage.cost
  end

  private

  #--
  #: () -> untyped
  def backend
    Riffer.config.tracing.backend || NoOp
  end
end
