# frozen_string_literal: true
# rbs_inline: enabled

# Generates anonymous Riffer::Tool subclasses from MCP tool definitions.
#
# Each generated class:
# - Has +.name+, +.description+, and +.parameters_schema+ derived from the MCP tool definition.
# - Delegates +#call+ to the MCP client's +tools_call+ method.
# - Skips Riffer's param validation — the MCP server validates inputs.
#
module Riffer::Mcp::ToolFactory
  # Builds one Riffer::Tool subclass per tool definition.
  #
  #--
  #: (Riffer::Mcp::Client, Array[Hash[Symbol, untyped]]) -> Array[singleton(Riffer::Tool)]
  def self.build(client, tool_defs)
    tool_defs.map { |td| build_tool_class(client, td) }
  end

  private_class_method def self.build_tool_class(client, td)
    Class.new(Riffer::Tool) do
      @mcp_client = client
      @mcp_tool_name = td[:name]
      # Set @identifier directly so .identifier does not fall back to
      # class_name_to_path(nil) on this anonymous class.
      @identifier = td[:name]

      define_singleton_method(:name) { td[:name] }
      define_singleton_method(:description) { td[:description] }
      # Pass the MCP inputSchema through without strict transforms.
      # MCP servers are expected to return strict-compatible schemas already.
      define_singleton_method(:parameters_schema) { |strict: false| td[:input_schema] || Riffer::Tool.send(:empty_schema) }

      define_method(:call) do |context:, **kwargs|
        result = self.class.instance_variable_get(:@mcp_client).tools_call(
          self.class.instance_variable_get(:@mcp_tool_name), kwargs
        )
        text(result)
      end
    end
  end
end
