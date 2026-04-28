# frozen_string_literal: true
# rbs_inline: enabled

# Per-server state managed by Riffer::Mcp::Registry.
#
# Created when a server is registered. Discovers tools via the MCP
# +tools/list+ call, then generates tool classes.
#
class Riffer::Mcp::Registration
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
    @tools = []
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

  # Runs tool discovery using the configured Runner.
  #
  # With +Runner::Sequential+ (default) discovery blocks inline. With
  # +Runner::Threaded+ discovery runs on a pool thread but +map+ still
  # blocks the caller — useful for Rails connection-pool isolation.
  #
  #--
  #: () -> void
  def run_discovery
    Riffer.config.mcp.discovery_runner.map([nil], context: nil) do |_|
      client = build_client
      tool_defs = client.tools_list
      tools = Riffer::Mcp::ToolFactory.build(client, tool_defs)

      @mutex.synchronize do
        next if @cancelled
        @tools = tools.freeze
      end
    end
  end

  #--
  #: () -> Riffer::Mcp::Client
  def build_client
    Riffer::Mcp::Client.new(endpoint: @manifest.endpoint, headers: @manifest.discovery_headers || {})
  end
end
