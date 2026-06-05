# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Lists or filters MCP tools by name or description during progressive discovery.
class Riffer::Mcp::SearchTool < Riffer::Tool
  IDENTIFIER = "mcp_search"

  identifier IDENTIFIER
  description "Search for available MCP tools by name or description."

  params do
    required :query, String, description: "Filter tools by name or description substring. Pass an empty string to list all tools."
  end

  # Searches progressive MCP tools by query.
  #--
  #: (context: Riffer::Agent::Context?, query: String) -> Riffer::Tools::Response
  def call(context:, query:)
    tools = context&.mcp_progressive_tools || []
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
