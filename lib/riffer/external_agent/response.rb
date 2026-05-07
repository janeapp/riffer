# frozen_string_literal: true
# rbs_inline: enabled

# Response from a Riffer::ExternalAgent#generate call.
#
# Adds +tool_calls+ to the standard Riffer::AgentResponse surface so callers
# can introspect the tools the agent invoked during generation.
#
#   response = agent.generate("search the docs")
#   response.content         # the assistant's reply text
#   response.tool_calls      # Array<Riffer::ExternalAgent::ToolCall>
#
class Riffer::ExternalAgent::Response < Riffer::AgentResponse
  # Tool calls the agent made during this generation.
  attr_reader :tool_calls #: Array[Riffer::ExternalAgent::ToolCall]

  # [content] the response content.
  # [messages] the full message history from the agent conversation.
  # [token_usage] optional token usage data.
  # [vendor_metadata] optional provider-specific metadata; frozen on construction.
  # [tool_calls] tool calls the agent made during this generation.
  # [resolved_identifier] optional agent identifier after alias resolution.
  #
  #--
  #: (String, ?messages: Array[Riffer::Messages::Base], ?token_usage: Riffer::TokenUsage?, ?vendor_metadata: Hash[Symbol, untyped], ?tool_calls: Array[Riffer::ExternalAgent::ToolCall], ?resolved_identifier: String?) -> void
  def initialize(content, messages: [], token_usage: nil, vendor_metadata: {}, tool_calls: [], resolved_identifier: nil)
    super(content, messages: messages, token_usage: token_usage, vendor_metadata: vendor_metadata, resolved_identifier: resolved_identifier)
    @tool_calls = tool_calls
  end
end
