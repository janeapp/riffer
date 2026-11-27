# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Tracing::ToolSpan # :nodoc: all
  extend self

  #--
  #: (Riffer::Messages::Assistant::ToolCall, Hash[String, String]) { () -> Riffer::Tools::Response } -> Riffer::Tools::Response
  def trace(tool_call, tags)
    Riffer::Tracing.in_span(
      "execute_tool #{tool_call.name}",
      attributes: attributes(tool_call, tags),
      kind: :internal,
    ) do |span|
      capture_arguments(span, tool_call)
      response = yield
      record_outcome(span, response)
      response
    rescue StandardError => e
      # The backend records the exception and error status on the re-raise;
      # error.type is the one semconv attribute it doesn't set.
      span.set_attribute("error.type", e.class.name)
      raise
    end
  end

  private

  #--
  #: (Riffer::Messages::Assistant::ToolCall, Hash[String, String]) -> Hash[String, untyped]
  def attributes(tool_call, tags)
    {
      "gen_ai.operation.name" => "execute_tool",
      "gen_ai.tool.name" => tool_call.name,
      "gen_ai.tool.call.id" => tool_call.call_id,
    }.merge(tags.transform_keys { |key| "riffer.tag.#{key}" })
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Riffer::Tools::Response) -> void
  def record_outcome(span, result)
    error_type = result.error_type
    span.set_attribute("error.type", error_type.to_s) if error_type

    # A deliberate error Response is a handled outcome, so only one carrying the
    # exception it was folded from gets an error status.
    exception = result.exception
    if exception
      span.record_exception(exception)
      span.error!(exception.message)
    end

    capture_result(span, result)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Riffer::Messages::Assistant::ToolCall) -> void
  def capture_arguments(span, tool_call)
    return unless capture_content?(span)

    span.set_attribute("gen_ai.tool.call.arguments", tool_call.arguments)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span), Riffer::Tools::Response) -> void
  def capture_result(span, result)
    return unless capture_content?(span)

    span.set_attribute("gen_ai.tool.call.result", result.content)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::NoOp::Span)) -> bool
  def capture_content?(span)
    Riffer.config.tracing.capture_messages && span.recording?
  end
end
