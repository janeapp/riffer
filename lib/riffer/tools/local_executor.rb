# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::Tools::LocalExecutor executes tools in-process.
#
# Wraps Tool classes, resolves tool calls by name, validates parameters,
# and invokes the tool with timeout handling. This is the default executor
# used by Riffer::Agent.
#
# See Riffer::Tools::Executor.
#
class Riffer::Tools::LocalExecutor < Riffer::Tools::Executor
  #: (Array[singleton(Riffer::Tool)]) -> void
  def initialize(tool_classes)
    @tool_classes = tool_classes
  end

  #: () -> Array[singleton(Riffer::Tool)]
  def tools_for_provider
    @tool_classes
  end

  #: (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response
  def execute(tool_call, context:)
    tool_class = find_tool_class(tool_call.name)

    if tool_class.nil?
      return Riffer::Tools::Response.error(
        "Unknown tool '#{tool_call.name}'",
        type: :unknown_tool
      )
    end

    tool_instance = tool_class.new
    arguments = parse_tool_arguments(tool_call.arguments)

    tool_instance.call_with_validation(context: context, **arguments)
  rescue Riffer::TimeoutError => e
    Riffer::Tools::Response.error(e.message, type: :timeout_error)
  rescue Riffer::ValidationError => e
    Riffer::Tools::Response.error(e.message, type: :validation_error)
  rescue => e
    Riffer::Tools::Response.error("Error executing tool: #{e.message}", type: :execution_error)
  end

  private

  #: (String) -> singleton(Riffer::Tool)?
  def find_tool_class(name)
    @tool_classes.find { |tool_class| tool_class.name == name }
  end

  #: ((String | Hash[String, untyped])?) -> Hash[Symbol, untyped]
  def parse_tool_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    args = arguments.is_a?(String) ? JSON.parse(arguments) : arguments
    args.transform_keys(&:to_sym)
  end
end
