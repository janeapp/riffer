# frozen_string_literal: true
# rbs_inline: enabled

# Per-server state managed by Riffer::Mcp::Registry — discovers tools via
# +tools/list+ and generates tool classes when a server is registered.
class Riffer::Mcp::Registration
  # @rbs @cancelled: bool
  # @rbs @tools: Array[singleton(Riffer::Tool)]
  # @rbs @mutex: Thread::Mutex

  # The manifest that describes this server.
  attr_reader :manifest #: Riffer::Mcp::Manifest

  # Generated Riffer::Tool subclasses.
  #
  #--
  #: () -> Array[singleton(Riffer::Tool)]
  def tools
    @mutex.synchronize { @tools }
  end

  #--
  #: (Riffer::Mcp::Manifest) -> void
  def initialize(manifest)
    @manifest = manifest
    @cancelled = false
    @tools = [] #: Array[singleton(Riffer::Tool)]
    @mutex = Mutex.new
    run_discovery
  end

  # Retires this registration, preventing in-flight discovery from publishing
  # state.
  #
  #--
  #: () -> void
  def retire!
    @mutex.synchronize { @cancelled = true }
  end

  # Returns true if this registration has been retired.
  #
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
