# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Handles tool call execution for an agent, composing with a Riffer::Runner for
# concurrency. Subclass and override +dispatch_tool_call+ to customize dispatch
# (e.g. HTTP, gRPC).
class Riffer::Tools::Runtime
  # @rbs @runner: Riffer::Runner

  #--
  #: (runner: Riffer::Runner) -> void
  def initialize(runner:)
    raise NotImplementedError, "#{self.class} is abstract — use a subclass like Riffer::Tools::Runtime::Inline" if instance_of?(Riffer::Tools::Runtime)
    @runner = runner
  end

  # Executes a batch of tool calls, returning <tt>[tool_call, response]</tt> pairs.
  #--
  #: (Array[Riffer::Messages::Assistant::ToolCall], tools: Array[singleton(Riffer::Tool)], context: Riffer::Agent::Context?, ?assistant_message: Riffer::Messages::Assistant?) -> Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response]]
  def execute(tool_calls, tools:, context:, assistant_message: nil)
    # Each Runner worker runs in its own thread/fiber, where the OTEL context
    # starts empty — capture here so the execute_tool span parents correctly.
    trace_context = Riffer::Tracing.current_context
    @runner.map(tool_calls, context: context) do |tool_call|
      Riffer::Tracing.with_context(trace_context) do
        in_tool_span(tool_call) do |span|
          result = around_tool_call(tool_call, context: context, assistant_message: assistant_message) do
            dispatch_tool_call(tool_call, tools: tools, context: context, assistant_message: assistant_message)
          end
          record_tool_outcome(span, result)
          [tool_call, result]
        end
      end
    end
  end

  # Hook wrapping each tool call; override in subclasses to instrument or
  # customize. Must +yield+ to continue.
  #
  #   class InstrumentedRuntime < Riffer::Tools::Runtime::Inline
  #     private
  #
  #     def around_tool_call(tool_call, context:, assistant_message: nil)
  #       start = Time.now
  #       result = yield
  #       Rails.logger.info("Tool #{tool_call.name} took #{Time.now - start}s")
  #       result
  #     end
  #   end
  #
  #--
  #: (Riffer::Messages::Assistant::ToolCall, context: Riffer::Agent::Context?, ?assistant_message: Riffer::Messages::Assistant?) { () -> Riffer::Tools::Response } -> Riffer::Tools::Response
  def around_tool_call(tool_call, context:, assistant_message: nil)
    yield
  end

  private

  #--
  #: (Riffer::Messages::Assistant::ToolCall, tools: Array[singleton(Riffer::Tool)], context: Riffer::Agent::Context?, ?assistant_message: Riffer::Messages::Assistant?) -> Riffer::Tools::Response
  def dispatch_tool_call(tool_call, tools:, context:, assistant_message: nil)
    tool_class = tools.find { |tc| tc.name == tool_call.name }

    if tool_class.nil?
      return Riffer::Tools::Response.error(
        "Unknown tool '#{tool_call.name}'",
        type: :unknown_tool
      )
    end

    tool_instance = tool_class.new
    arguments = parse_arguments(tool_call.arguments)

    tool_instance.call_with_validation(context: context, **arguments)
  rescue Riffer::TimeoutError => e
    Riffer::Tools::Response.error(e.message, type: :timeout_error)
  rescue Riffer::ValidationError => e
    Riffer::Tools::Response.error(e.message, type: :validation_error)
  rescue Riffer::ToolExecutionError => e
    Riffer::Tools::Response.error(e.message, type: :execution_error)
  rescue RuntimeError => e
    Riffer::Tools::Response.error("Error executing tool: #{e.message}", type: :execution_error)
  end

  #--
  #: (String?) -> Hash[Symbol, untyped]
  def parse_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    JSON.parse(arguments, symbolize_names: true)
  end

  # Emitted outside +around_tool_call+ so host enrichment spans nest beneath it.
  #--
  #: [R] (Riffer::Messages::Assistant::ToolCall) { ((Riffer::Tracing::Otel::Span | Riffer::Tracing::Null::Span)) -> R } -> R
  def in_tool_span(tool_call)
    Riffer::Tracing.in_span("execute_tool #{tool_call.name}", attributes: tool_span_attributes(tool_call), kind: :internal) do |span|
      capture_tool_arguments(span, tool_call)
      yield span
    rescue => error
      # The backend records the exception and error status on the re-raise;
      # error.type is the one semconv attribute it doesn't set.
      span.set_attribute("error.type", error.class.name)
      raise
    end
  end

  #--
  #: (Riffer::Messages::Assistant::ToolCall) -> Hash[String, untyped]
  def tool_span_attributes(tool_call)
    {
      "gen_ai.operation.name" => "execute_tool",
      "gen_ai.tool.name" => tool_call.name,
      "gen_ai.tool.call.id" => tool_call.call_id
    }
  end

  # A returned error Response is a handled outcome, so its status stays unset —
  # an error span status is reserved for a raised exception.
  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::Null::Span), Riffer::Tools::Response) -> void
  def record_tool_outcome(span, result)
    error_type = result.error_type
    span.set_attribute("error.type", error_type.to_s) if error_type
    capture_tool_result(span, result)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::Null::Span), Riffer::Messages::Assistant::ToolCall) -> void
  def capture_tool_arguments(span, tool_call)
    return unless capture_tool_content?(span)

    arguments = tool_call.arguments
    span.set_attribute("gen_ai.tool.call.arguments", arguments) if arguments
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::Null::Span), Riffer::Tools::Response) -> void
  def capture_tool_result(span, result)
    return unless capture_tool_content?(span)

    span.set_attribute("gen_ai.tool.call.result", result.content)
  end

  #--
  #: ((Riffer::Tracing::Otel::Span | Riffer::Tracing::Null::Span)) -> bool
  def capture_tool_content?(span)
    Riffer.config.tracing.capture_messages && span.recording?
  end
end
