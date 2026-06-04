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
    @runner.map(tool_calls, context: context) do |tool_call|
      result = around_tool_call(tool_call, context: context, assistant_message: assistant_message) do
        dispatch_tool_call(tool_call, tools: tools, context: context, assistant_message: assistant_message)
      end
      [tool_call, result]
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
end
