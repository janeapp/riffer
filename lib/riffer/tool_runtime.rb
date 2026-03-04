# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::ToolRuntime handles tool call execution for an agent.
#
# Composes with a Riffer::Runner for concurrency control and provides
# +execute+ as the sole public entry point.
#
# Subclass and override +dispatch_tool_call+ to customize how individual
# tool calls are dispatched (e.g., HTTP, gRPC).
#
#   runtime = Riffer::ToolRuntime::Inline.new
#   results = runtime.execute(tool_calls, tools: tools, context: ctx)
#
class Riffer::ToolRuntime
  # +runner+ - the concurrency runner to use for batch execution.
  #
  # Subclasses must provide a runner; instantiating ToolRuntime directly
  # raises +NotImplementedError+.
  #
  #: (runner: Riffer::Runner) -> void
  def initialize(runner:)
    raise NotImplementedError, "#{self.class} is abstract — use a subclass like Riffer::ToolRuntime::Inline" if instance_of?(Riffer::ToolRuntime)
    @runner = runner
  end

  # Executes a batch of tool calls, returning +[tool_call, response]+ pairs.
  #
  # +tool_calls+ - the tool calls to execute.
  # +tools+ - the resolved tool classes.
  # +context+ - the tool context hash.
  #
  #: (Array[Riffer::Messages::Assistant::ToolCall], tools: Array[singleton(Riffer::Tool)], context: Hash[Symbol, untyped]?) -> Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response]]
  def execute(tool_calls, tools:, context:)
    @runner.map(tool_calls) do |tool_call|
      result = around_tool_call(tool_call, context: context) do
        dispatch_tool_call(tool_call, tools: tools, context: context)
      end
      [tool_call, result]
    end
  end

  # Hook that wraps each tool call execution. Override in subclasses
  # to customize. Must +yield+ to continue execution.
  #
  # The default implementation simply yields.
  #
  #   class InstrumentedRuntime < Riffer::ToolRuntime::Inline
  #     private
  #
  #     def around_tool_call(tool_call, context:)
  #       start = Time.now
  #       result = yield
  #       Rails.logger.info("Tool #{tool_call.name} took #{Time.now - start}s")
  #       result
  #     end
  #   end
  #
  #: (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) { () -> Riffer::Tools::Response } -> Riffer::Tools::Response
  def around_tool_call(tool_call, context:)
    yield
  end

  private

  # Dispatches a single tool call. Override in subclasses to change
  # how individual tools are invoked (e.g., HTTP, gRPC).
  #
  # +tool_call+ - the tool call to execute.
  # +tools+ - the resolved tool classes.
  # +context+ - the tool context hash.
  #
  #: (Riffer::Messages::Assistant::ToolCall, tools: Array[singleton(Riffer::Tool)], context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response
  def dispatch_tool_call(tool_call, tools:, context:)
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

  #: (String?) -> Hash[Symbol, untyped]
  def parse_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    JSON.parse(arguments, symbolize_names: true)
  end
end
