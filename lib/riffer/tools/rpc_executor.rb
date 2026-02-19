# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Tools::RpcExecutor delegates tool execution to a callback.
#
# Used in the RPC architecture where tool definitions travel to the agent
# server for the LLM, but execution happens on the client via a callback.
#
# See Riffer::Tools::Executor.
#
#   executor = Riffer::Tools::RpcExecutor.new(
#     tool_proxies,
#     callback: ->(tool_call, context:) { Riffer::Tools::Response.text("ok") }
#   )
#
class Riffer::Tools::RpcExecutor < Riffer::Tools::Executor
  #: (Array[Riffer::Tools::ToolProxy], callback: ^(Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response) -> void
  def initialize(tool_proxies, callback:)
    @tool_proxies = tool_proxies
    @callback = callback
  end

  #: () -> Array[Riffer::Tools::ToolProxy]
  def tools_for_provider
    @tool_proxies
  end

  #: (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response
  def execute(tool_call, context:)
    unless @tool_proxies.any? { |proxy| proxy.name == tool_call.name }
      return Riffer::Tools::Response.error(
        "Unknown tool '#{tool_call.name}'",
        type: :unknown_tool
      )
    end

    @callback.call(tool_call, context: context)
  rescue => e
    Riffer::Tools::Response.error("Error executing tool: #{e.message}", type: :execution_error)
  end
end
