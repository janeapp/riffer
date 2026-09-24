# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Mcp::Registration
  # @rbs @cancelled: bool
  # @rbs @tools: Array[singleton(Riffer::Mcp::Tool)]
  # @rbs @mutex: Thread::Mutex

  attr_reader :manifest #: Riffer::Mcp::Manifest # @dynamic manifest

  #--
  #: () -> Array[singleton(Riffer::Mcp::Tool)]
  def tools
    @mutex.synchronize { @tools }
  end

  #--
  #: (Riffer::Mcp::Manifest) -> void
  def initialize(manifest)
    @manifest = manifest
    @cancelled = false
    @tools = [] #: Array[singleton(Riffer::Mcp::Tool)]
    @mutex = Mutex.new
    run_discovery
  end

  #--
  #: () -> void
  def retire!
    @mutex.synchronize { @cancelled = true }
  end

  #--
  #: () -> bool
  def retired?
    @mutex.synchronize { @cancelled }
  end

  private

  #--
  #: () -> void
  def run_discovery
    Riffer.config.mcp.discovery_runner.map([nil], context: nil) do |_|
      client = build_client
      tool_defs = client.tools_list
      tools = Riffer::Mcp::ToolFactory.build(@manifest.name, client, tool_defs)

      @mutex.synchronize do
        @tools = tools.freeze unless @cancelled
      end
    end
  end

  #--
  #: () -> Riffer::Mcp::Client
  def build_client
    Riffer::Mcp::Client.new(endpoint: @manifest.endpoint, headers: @manifest.discovery_headers || {})
  end
end
