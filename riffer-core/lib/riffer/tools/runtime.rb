# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::Tools::Runtime
  # @rbs @runner: Riffer::Runner

  #--
  #: (runner: Riffer::Runner) -> void
  def initialize(runner:)
    if instance_of?(Riffer::Tools::Runtime)
      raise NotImplementedError,
            "#{self.class} is abstract — use a subclass like Riffer::Tools::Runtime::Inline"
    end

    @runner = runner
  end

  #--
  #: (Array[Riffer::Messages::Assistant::ToolCall], tools: Array[singleton(Riffer::Tool)], context: Riffer::Agent::Context?, ?assistant_message: Riffer::Messages::Assistant?, ?tags: Hash[String, String]) -> Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response]]
  def execute(tool_calls, tools:, context:, assistant_message: nil, tags: {})
    # Each Runner worker runs in its own thread/fiber, where the OTEL context
    # starts empty — capture here so the execute_tool span parents correctly.
    trace_context = Riffer::Tracing.current_context
    @runner.map(tool_calls, context: context) do |tool_call|
      Riffer::Tracing.with_context(trace_context) do
        # Outside around_tool_call so host enrichment spans nest beneath it.
        result = Riffer::Tracing::ToolSpan.trace(tool_call, tags) do
          around_tool_call(tool_call, context: context, assistant_message: assistant_message) do
            dispatch_tool_call(tool_call, tools: tools, context: context, assistant_message: assistant_message)
          end
        end
        [tool_call, result]
      end
    end
  end

  # Overrides must +yield+ and return its Response.
  #--
  #: (Riffer::Messages::Assistant::ToolCall, context: Riffer::Agent::Context?, ?assistant_message: Riffer::Messages::Assistant?) { () -> Riffer::Tools::Response } -> Riffer::Tools::Response
  def around_tool_call(_tool_call, context:, assistant_message: nil)
    yield
  end

  private

  # Subclasses override this to dispatch elsewhere (e.g. HTTP, gRPC).
  #--
  #: (Riffer::Messages::Assistant::ToolCall, tools: Array[singleton(Riffer::Tool)], context: Riffer::Agent::Context?, ?assistant_message: Riffer::Messages::Assistant?) -> Riffer::Tools::Response
  def dispatch_tool_call(tool_call, tools:, context:, assistant_message: nil)
    tool_class = tools.find { |tc| tc.name == tool_call.name }

    if tool_class.nil?
      return Riffer::Tools::Response.error(
        "Unknown tool '#{tool_call.name}'",
        type: :unknown_tool,
      )
    end

    tool_instance = tool_class.new
    arguments = parse_arguments(tool_call.arguments)

    unless arguments.is_a?(Hash)
      return Riffer::Tools::Response.error(
        "Invalid JSON in tool arguments: expected an object, got #{arguments.class}",
        type: :validation_error,
      )
    end

    tool_instance.call_with_validation(context: context, **arguments)
  rescue JSON::ParserError => e
    Riffer::Tools::Response.error("Invalid JSON in tool arguments: #{e.message}", type: :validation_error)
  end

  #--
  #: (String) -> untyped
  def parse_arguments(arguments)
    return {} if arguments.empty?

    JSON.parse(arguments, symbolize_names: true)
  end
end
