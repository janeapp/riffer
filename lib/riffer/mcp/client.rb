# frozen_string_literal: true
# rbs_inline: enabled

# Thin wrapper around the MCP Ruby SDK client (mcp gem v0.8+). Resolves headers
# (if a Proc) once at init, then provides +tools_list+ / +tools_call+ — used for
# discovery and for +tools/call+ when no +credentials+ proc is configured.
class Riffer::Mcp::Client
  # @rbs @client: untyped

  #--
  #: (endpoint: String, ?headers: (Hash[String, String] | Proc), ?client: untyped?) -> void
  def initialize(endpoint:, headers: {}, client: nil)
    depends_on "mcp"
    depends_on "faraday"

    @client = client || begin
      resolved_headers = Riffer::Helpers::CallOrValue.resolve(headers)
      transport = MCP::Client::HTTP.new(url: endpoint, headers: resolved_headers)
      MCP::Client.new(transport: transport)
    end
  end

  # Returns tool definition hashes with +:name+, +:description+, and
  # +:input_schema+ keys.
  #--
  #: () -> Array[Hash[Symbol, untyped]]
  def tools_list
    @client.tools.map do |tool|
      {
        name: tool.name,
        description: tool.description,
        input_schema: tool.input_schema
      }
    end
  end

  # Calls a tool on the MCP server and returns joined text content from the response.
  #
  #--
  #: (String, ?Hash[untyped, untyped]) -> String
  def tools_call(name, arguments = {})
    tool = MCP::Client::Tool.new(name: name, description: nil, input_schema: nil)
    response = @client.call_tool(tool: tool, arguments: arguments)

    if response["error"]
      raise Riffer::Error, response.dig("error", "message") || "MCP tool call failed"
    end

    if response.dig("result", "isError")
      message = (response.dig("result", "content") || []).filter_map { |item| item["text"] }.join
      raise Riffer::Error, message.empty? ? "MCP tool '#{name}' failed" : message
    end

    content = response.dig("result", "content") || []
    content.filter_map { |item| item["text"] }.join
  end

  private

  #: (String) -> true
  def depends_on(gem_name)
    Riffer::Helpers::Dependencies.depends_on(gem_name)
  end
end
