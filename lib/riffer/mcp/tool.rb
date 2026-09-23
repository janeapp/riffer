# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Mcp::Tool < Riffer::Tool
  # @rbs self.@mcp_server_tool_name: String?
  # @rbs self.@input_schema: Hash[Symbol, untyped]?

  #--
  #: () -> String
  def self.mcp_server_tool_name
    @mcp_server_tool_name || raise(NotImplementedError, "#{self} must set @mcp_server_tool_name")
  end

  #--
  #: (?strict: bool) -> Hash[Symbol, untyped]
  def self.parameters_schema(strict: false)
    # MCP schemas are server-defined, so +strict+ is not applied to them.
    @input_schema || super
  end
end
