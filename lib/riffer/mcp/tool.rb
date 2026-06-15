# frozen_string_literal: true
# rbs_inline: enabled

# Base class for MCP-generated tools.
class Riffer::Mcp::Tool < Riffer::Tool
  # @rbs self.@mcp_server_tool_name: String?
  # @rbs self.@input_schema: Hash[Symbol, untyped]?

  # Returns the unprefixed tool name used for +tools/call+ on the MCP server.
  #--
  #: () -> String
  def self.mcp_server_tool_name
    @mcp_server_tool_name || raise(NotImplementedError, "#{self} must set @mcp_server_tool_name")
  end

  # Returns the server-published input schema, falling back to the params DSL.
  # MCP schemas are server-defined, so +strict+ is not applied to them.
  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def self.parameters_schema(strict: false)
    @input_schema || super
  end
end
