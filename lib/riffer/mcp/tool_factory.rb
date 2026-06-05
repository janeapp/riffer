# frozen_string_literal: true
# rbs_inline: enabled

# Generates anonymous Riffer::Tool subclasses from MCP tool definitions.
# Generated tools delegate +#call+ to the MCP client and skip Riffer's param
# validation — the MCP server validates inputs.
module Riffer::Mcp::ToolFactory
  extend self

  # Builds one Riffer::Tool subclass per tool definition, prefixing names with
  # the manifest name to avoid cross-server collisions (e.g. +jira__search+);
  # the server-side name stays on +.mcp_server_tool_name+.
  #--
  #: (String, Riffer::Mcp::Client, Array[Hash[Symbol, untyped]]) -> Array[singleton(Riffer::Tool)]
  def build(manifest_name, client, tool_defs)
    tool_defs.map { |td| build_tool_class(manifest_name, client, td) }
  end

  private

  #: (String) -> String
  def sanitize_name_component(str)
    str.gsub(/[^a-zA-Z0-9_-]/, "_")
  end

  def build_tool_class(manifest_name, client, td)
    prefixed = "#{sanitize_name_component(manifest_name)}__#{sanitize_name_component(td[:name])}"

    # steep cannot type the body of a dynamically created anonymous class:
    # its ivars and `self` inside define_method are unresolvable, so the
    # block is ignored wholesale (cf. AuthenticatedTool.wrap_one).
    Class.new(Riffer::Tool) do
      # steep:ignore:start
      @mcp_client = client
      @mcp_server_tool_name = td[:name]
      # Set @identifier directly so .identifier does not fall back to
      # Riffer::Helpers::ClassNameConverter.convert(nil) on this anonymous class.
      @identifier = prefixed

      define_singleton_method(:name) { prefixed }
      define_singleton_method(:mcp_server_tool_name) { td[:name] }
      define_singleton_method(:description) { td[:description] }
      define_singleton_method(:parameters_schema) { |strict: false| td[:input_schema] || Riffer::Tool.send(:empty_schema) }

      define_method(:call) do |context:, **kwargs|
        result = self.class.instance_variable_get(:@mcp_client).tools_call(
          self.class.instance_variable_get(:@mcp_server_tool_name), kwargs
        )
        text(result)
      end
      # steep:ignore:end
    end
  end
end
