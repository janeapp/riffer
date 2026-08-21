# frozen_string_literal: true
# rbs_inline: enabled

# Searches available MCP tools by name or description.
class Riffer::Mcp::SearchTool < Riffer::Tool
  IDENTIFIER = "mcp_search"

  # Successful search response carrying the matched tool classes.
  class Result < Riffer::Tools::Response
    # Tool classes that matched the search query.
    attr_reader :discovered_tools #: Array[singleton(Riffer::Tool)]

    #--
    #: (String, Array[singleton(Riffer::Tool)]) -> void
    def initialize(content, discovered_tools)
      super(content: content, success: true)
      @discovered_tools = discovered_tools
    end
  end

  identifier IDENTIFIER
  description "Search for available MCP tools by name or description."

  params do
    required :query, String, description: "Non-empty substring to filter tools by name or description."
  end

  # Searches progressive MCP tools and returns a +Result+ with +discovered_tools+.
  #--
  #: (context: Riffer::Agent::Context?, query: String) -> Riffer::Tools::Response
  def call(context:, query:)
    return error("Provide a search query to find MCP tools by name or description.") if query.strip.empty?

    tools = context&.mcp_progressive_tools || []
    matches = filter(tools, query)

    return text("No tools found matching '#{query}'.") if matches.empty?

    names = matches.map(&:name).join(", ")
    Result.new(
      "Found #{matches.length} tool(s): #{names}. They are now available — call them directly.",
      matches,
    )
  end

  private

  #: (Array[singleton(Riffer::Tool)], String) -> Array[singleton(Riffer::Tool)]
  def filter(tools, query)
    q = query.downcase
    tools.select { |t| t.name.downcase.include?(q) || t.description.to_s.downcase.include?(q) }
  end
end
