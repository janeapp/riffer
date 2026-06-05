# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Invokes an MCP tool by name during progressive discovery.
# Arguments are JSON-encoded because strict-mode providers prohibit open-ended object schemas.
class Riffer::Mcp::CallTool < Riffer::Tool
  IDENTIFIER = "mcp_call"

  identifier IDENTIFIER
  description "Invoke an MCP tool by its name as returned by mcp_search (e.g. 'github__create_pr')."

  params do
    required :tool_name, String, description: "Tool name as returned by mcp_search (e.g. 'github__create_pr')."
    optional :arguments, String, description: "JSON-encoded object of arguments to pass to the tool."
  end

  # Invokes the named MCP tool.
  #--
  #: (context: Riffer::Agent::Context?, tool_name: String, ?arguments: String?) -> Riffer::Tools::Response
  def call(context:, tool_name:, arguments: nil)
    return error("'tool_name' must be a non-empty string.") if tool_name.strip.empty?

    tools = context&.mcp_progressive_tools || []
    target = tools.find { |t| t.name == tool_name }
    return error("Tool '#{tool_name}' not found. Use mcp_search to discover available tools.") unless target

    parsed = parse_arguments(arguments)
    return parsed if parsed.is_a?(Riffer::Tools::Response)

    target.new.call(context: context, **parsed)
  rescue ArgumentError => e
    error("Argument error calling '#{tool_name}': #{e.message}. Use mcp_search to confirm the expected schema.")
  end

  private

  #: (String?) -> (Hash[Symbol, untyped] | Riffer::Tools::Response)
  def parse_arguments(arguments)
    return {} if arguments.nil? || arguments.strip.empty?

    result = JSON.parse(arguments, symbolize_names: true)
    unless result.is_a?(Hash)
      return error("'arguments' must be a JSON object, got #{result.class.name.downcase}.")
    end
    result
  rescue JSON::ParserError => e
    error("Invalid JSON in 'arguments': #{e.message}")
  end
end
