# frozen_string_literal: true
# rbs_inline: enabled

require "json"

class Riffer::ToolRuntime
  #: (runner: Riffer::Runner) -> void
  def initialize(runner:)
    raise NotImplementedError, "#{self.class} is abstract — use a subclass like Riffer::ToolRuntime::Inline" if instance_of?(Riffer::ToolRuntime)
    @runner = runner
  end

  #: (Array[Riffer::Messages::Assistant::ToolCall], tools: Array[singleton(Riffer::Tool)], context: Hash[Symbol, untyped]?) -> Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response]]
  def execute(tool_calls, tools:, context:)
    @runner.map(tool_calls) do |tool_call|
      result = around_tool_call(tool_call, context: context) do
        dispatch_tool_call(tool_call, tools: tools, context: context)
      end
      [tool_call, result]
    end
  end

  #: (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) { () -> Riffer::Tools::Response } -> Riffer::Tools::Response
  def around_tool_call(tool_call, context:)
    yield
  end

  private

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
