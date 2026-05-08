# frozen_string_literal: true
# rbs_inline: enabled

# Builds MCP-gem-compatible tool classes from +Riffer::Tool+ subclasses.
#
# Each call to +.build_for+ returns an anonymous +MCP::Tool+ subclass that:
#   1. Mirrors the source tool's name, description, and strict input schema.
#   2. On +self.call+, instantiates the source tool and dispatches via
#      +Riffer::Tool#call_with_validation+ — so the same validation, timeout,
#      and return-type guarantees apply at the HTTP boundary as elsewhere.
#   3. Translates +Riffer::ValidationError+, +Riffer::TimeoutError+, and any
#      other +StandardError+ into an error +MCP::Tool::Response+ carrying the
#      message but never the backtrace.
#
# Dispatch deliberately bypasses +Riffer::ToolRuntime+: that runtime exists to
# convert exceptions back into +Response.error+ objects for an outer agent
# loop, but here the MCP server *is* the outer loop and we want exceptions to
# surface at the HTTP boundary.
class Riffer::McpServer::ToolAdapter
  extend Riffer::Helpers::Dependencies

  # Builds an MCP::Tool subclass that proxies into the given +Riffer::Tool+ class.
  #
  # Raises +Riffer::ArgumentError+ if the source tool is missing a description
  # or identifier (MCP requires both).
  #
  #--
  #: (Class) -> untyped
  def self.build_for(tool_class)
    depends_on "mcp"
    tool_class.validate_as_tool!

    name = tool_class.name
    description = tool_class.description
    schema = sanitize_schema_for_mcp(tool_class.parameters_schema(strict: true))

    Class.new(MCP::Tool) do
      tool_name name
      description description
      input_schema schema

      define_singleton_method(:call) do |server_context: nil, **args|
        riffer_context = extract_riffer_context(server_context)
        response = tool_class.new.call_with_validation(context: riffer_context, **args)
        success_response(response)
      rescue Riffer::ValidationError => e
        error_response(e.message)
      rescue Riffer::TimeoutError => e
        error_response(e.message)
      rescue => e
        error_response("#{e.class}: #{e.message}")
      end

      define_singleton_method(:extract_riffer_context) do |server_context|
        return {} if server_context.nil?
        server_context[:riffer_context] || {}
      end

      define_singleton_method(:success_response) do |riffer_response|
        MCP::Tool::Response.new([{type: "text", text: riffer_response.content.to_s}])
      end

      define_singleton_method(:error_response) do |message|
        MCP::Tool::Response.new([{type: "text", text: message}], error: true)
      end
    end
  end

  # MCP's draft-04 schema validator rejects an empty +required+ array; strip
  # it out when the source tool defined no parameters at all.
  #
  #--
  #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def self.sanitize_schema_for_mcp(schema)
    return schema unless schema.is_a?(Hash) && schema[:required].is_a?(Array) && schema[:required].empty?
    schema.except(:required)
  end
end
