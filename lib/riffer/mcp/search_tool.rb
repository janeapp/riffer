# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Progressive-discovery search tool. Lists or filters MCP tools by name or description.
#
# Reads the per-agent set of auth-wrapped MCP tool classes from
# +context[:mcp_progressive_tools]+ (populated by Riffer::Agent when a
# progressive +use_mcp+ matches at least one registration).
#
# See Riffer::Agent.use_mcp and docs/14_MCP.md.
class Riffer::Mcp::SearchTool < Riffer::Tool
  IDENTIFIER = "mcp_search" #: String

  identifier IDENTIFIER
  description "Search for available MCP tools by name or description."

  params do
    required :query, String, description: "Filter tools by name or description substring. Pass an empty string to list all tools."
  end

  # [context] tool context containing +:mcp_progressive_tools+ (Array of Riffer::Tool subclasses).
  # [query]   substring filter; an empty string returns all tools.
  #
  #--
  #: (context: Hash[Symbol, untyped]?, query: String) -> Riffer::Tools::Response
  def call(context:, query:)
    tools = context&.dig(:mcp_progressive_tools) || []
    matches = filter(tools, query)

    if matches.empty?
      msg = query.strip.empty? ? "No tools available." : "No tools found matching '#{query}'."
      return text(msg)
    end

    text(format_matches(matches))
  end

  private

  #: (Array[singleton(Riffer::Tool)], String) -> Array[singleton(Riffer::Tool)]
  def filter(tools, query)
    return tools if query.strip.empty?
    q = query.downcase
    tools.select { |t| t.name.downcase.include?(q) || t.description.to_s.downcase.include?(q) }
  end

  #: (Array[singleton(Riffer::Tool)]) -> String
  def format_matches(matches)
    matches.map { |t|
      "#{t.name}: #{t.description}\n  #{JSON.generate(t.parameters_schema(strict: false))}"
    }.join("\n")
  end
end
