# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::ToolRuntime handles tool call execution for an agent.
#
# Composes with a Riffer::Runner for concurrency control and provides
# +execute+ (batch) and +call+ (single-call) methods.
#
# Subclass to customize execution behavior (e.g., HTTP dispatch,
# background jobs).
#
#   runtime = Riffer::ToolRuntime::Inline.new
#   results = runtime.execute(tool_calls, tools: tools, context: ctx)
#
class Riffer::ToolRuntime
  # +runner+ - the concurrency runner to use for batch execution.
  #
  #: (?runner: Riffer::Runner) -> void
  def initialize(runner: Riffer::Runner::Sequential.new)
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
      result = with_execution_context(tool_call, context: context) do
        call(tool_call, tools: tools, context: context)
      end
      [tool_call, result]
    end
  end

  # Executes a single tool call.
  #
  # +tool_call+ - the tool call to execute.
  # +tools+ - the resolved tool classes.
  # +context+ - the tool context hash.
  #
  #: (Riffer::Messages::Assistant::ToolCall, tools: Array[singleton(Riffer::Tool)], context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response
  def call(tool_call, tools:, context:)
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
  rescue => e
    Riffer::Tools::Response.error("Error executing tool: #{e.message}", type: :execution_error)
  end

  # Registers an around-execution callback on this class.
  #
  # The block receives +tool_call+, +context:+, and must yield to
  # continue the chain.
  #
  #   class MyRuntime < Riffer::ToolRuntime
  #     around_tool_execution do |tool_call, context:, &block|
  #       puts "Before #{tool_call.name}"
  #       result = block.call
  #       puts "After #{tool_call.name}"
  #       result
  #     end
  #   end
  #
  #: () { (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response } -> void
  def self.around_tool_execution(&block)
    execution_callbacks << block
  end

  # Returns the registered around-execution callbacks for this class.
  #
  #: () -> Array[Proc]
  def self.execution_callbacks
    @execution_callbacks ||= []
  end

  private

  #: (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) { () -> Riffer::Tools::Response } -> Riffer::Tools::Response
  def with_execution_context(tool_call, context:, &block)
    callbacks = self.class.execution_callbacks
    return block.call if callbacks.empty?

    chain = callbacks.reverse.reduce(block) do |next_block, callback|
      -> { callback.call(tool_call, context: context, &next_block) }
    end

    chain.call
  end

  #: ((String | Hash[String, untyped])?) -> Hash[Symbol, untyped]
  def parse_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    args = arguments.is_a?(String) ? JSON.parse(arguments) : arguments
    args.transform_keys(&:to_sym)
  end
end
