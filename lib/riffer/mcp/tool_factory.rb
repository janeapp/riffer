# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Mcp::ToolFactory
  extend self

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
    # Prefixed to avoid cross-server collisions; the server-side name stays on
    # mcp_server_tool_name.
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

      # No Riffer param validation — the MCP server validates inputs.
      define_method(:call) do |context:, **kwargs|
        text(client.tools_call(self.class.mcp_server_tool_name, kwargs))
      end
      # steep:ignore:end
    end #: singleton(Riffer::Mcp::Tool)
  end
end
