# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Riffer::AgentRuntime handles subagent call execution for a supervisor agent.
#
# Composes with a Riffer::Runner for concurrency control and provides
# +execute+ as the sole public entry point.
#
# Mirrors Riffer::ToolRuntime structure but dispatches agent calls
# directly (not through tools) — agents are always in-process I/O.
#
#   runtime = Riffer::AgentRuntime::Inline.new
#   results = runtime.execute(tool_calls, agents: agent_map, context: context)
#
class Riffer::AgentRuntime
  # +runner+ - the concurrency runner to use for batch execution.
  #
  # Subclasses must provide a runner; instantiating AgentRuntime directly
  # raises +NotImplementedError+.
  #
  #: (runner: Riffer::Runner) -> void
  def initialize(runner:)
    raise NotImplementedError, "#{self.class} is abstract — use a subclass like Riffer::AgentRuntime::Inline" if instance_of?(Riffer::AgentRuntime)
    @runner = runner
  end

  # Executes a batch of agent calls, returning +[tool_call, response]+ pairs.
  #
  # +tool_calls+ - the tool calls to execute (agent tool calls).
  # +agents+ - Hash mapping agent tool names to agent classes.
  # +context+ - the context hash.
  #
  #: (Array[Riffer::Messages::Assistant::ToolCall], agents: Hash[String, singleton(Riffer::Agent)], context: Hash[Symbol, untyped]?) -> Array[[Riffer::Messages::Assistant::ToolCall, Riffer::Tools::Response]]
  def execute(tool_calls, agents:, context:)
    @runner.map(tool_calls) do |tool_call|
      result = around_agent_call(tool_call, context: context) do
        dispatch_agent_call(tool_call, agents: agents, context: context)
      end
      [tool_call, result]
    end
  end

  # Hook that wraps each agent call execution. Override in subclasses
  # to customize. Must +yield+ to continue execution.
  #
  #: (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) { () -> Riffer::Tools::Response } -> Riffer::Tools::Response
  def around_agent_call(tool_call, context:)
    yield
  end

  private

  # Dispatches a single agent call.
  #
  #: (Riffer::Messages::Assistant::ToolCall, agents: Hash[String, singleton(Riffer::Agent)], context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response
  def dispatch_agent_call(tool_call, agents:, context:)
    agent_class = agents[tool_call.name]

    unless agent_class
      return Riffer::Tools::Response.error(
        "Unknown agent '#{tool_call.name}'",
        type: :unknown_agent
      )
    end

    message = parse_arguments(tool_call.arguments)[:message]
    response = agent_class.new.generate(message, context: context)

    if response.blocked?
      Riffer::Tools::Response.error(
        "Agent was blocked: #{response.tripwire&.reason || "guardrail triggered"}",
        type: :execution_error
      )
    elsif response.interrupted?
      Riffer::Tools::Response.text("Agent was interrupted: #{response.content}")
    else
      Riffer::Tools::Response.text(response.content)
    end
  rescue RuntimeError => e
    Riffer::Tools::Response.error("Error executing agent: #{e.message}", type: :execution_error)
  end

  #: (String?) -> Hash[Symbol, untyped]
  def parse_arguments(arguments)
    return {} if arguments.nil? || arguments.empty?

    JSON.parse(arguments, symbolize_names: true)
  end
end
