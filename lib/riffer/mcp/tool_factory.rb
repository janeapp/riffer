# frozen_string_literal: true
# rbs_inline: enabled

# Generates anonymous Riffer::Mcp::Tool subclasses from MCP tool definitions.
# Generated tools delegate +#call+ to the MCP client and skip Riffer's param
# validation — the MCP server validates inputs.
module Riffer::Mcp::ToolFactory
  extend self

  # Builds one Riffer::Mcp::Tool subclass per tool definition, prefixing names
  # with the manifest name to avoid cross-server collisions (e.g.
  # +jira__search+); the server-side name stays on +.mcp_server_tool_name+.
  #--
  #: (String, Riffer::Mcp::Client, Array[Hash[Symbol, untyped]]) -> Array[singleton(Riffer::Mcp::Tool)]
  def build(manifest_name, client, tool_defs)
    tool_defs.map { |td| build_tool_class(manifest_name, client, td) }
  end

  private

  #: (String) -> String
  def sanitize_name_component(str)
    str.gsub(/[^a-zA-Z0-9_-]/, "_")
  end

  #: (String, Riffer::Mcp::Client, Hash[Symbol, untyped]) -> singleton(Riffer::Mcp::Tool)
  def build_tool_class(manifest_name, client, descriptor)
    prefixed = "#{sanitize_name_component(manifest_name)}__#{sanitize_name_component(descriptor[:name])}"

    # steep does not model Class.new's class_eval semantics — the block body
    # typechecks against the enclosing module, so the ivar assignments and the
    # define_method body are unresolvable.
    Class.new(Riffer::Mcp::Tool) do
      # steep:ignore:start
      @mcp_server_tool_name = descriptor[:name]
      @identifier = prefixed
      @description = descriptor[:description]
      @input_schema = descriptor[:input_schema]

      define_method(:call) do |context:, **kwargs|
        text(client.tools_call(self.class.mcp_server_tool_name, kwargs))
      end
      # steep:ignore:end
    end #: singleton(Riffer::Mcp::Tool)
  end
end
