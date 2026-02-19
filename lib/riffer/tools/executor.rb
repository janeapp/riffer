# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Tools::Executor is the abstract base class for tool execution strategies.
#
# Subclasses must implement +#tools_for_provider+ and +#execute+.
#
# See Riffer::Tools::LocalExecutor and Riffer::Tools::RpcExecutor.
#
class Riffer::Tools::Executor
  # Returns tool descriptors for the LLM provider.
  #
  #: () -> Array[untyped]
  def tools_for_provider
    raise NotImplementedError
  end

  # Executes a tool call and returns a response.
  #
  #: (Riffer::Messages::Assistant::ToolCall, context: Hash[Symbol, untyped]?) -> Riffer::Tools::Response
  def execute(tool_call, context:)
    raise NotImplementedError
  end
end
