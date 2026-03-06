# frozen_string_literal: true
# rbs_inline: enabled

# Per-server state managed by Riffer::Mcp::Registry.
#
# Created when a server is registered. Spawns a background thread to discover
# tools via the MCP +tools/list+ call, then generates tool classes.
#
class Riffer::Mcp::Registration
  # The manifest that describes this server.
  attr_reader :manifest #: Riffer::Mcp::Manifest

  # Generated Riffer::Tool subclasses (empty until discovery completes).
  #
  #--
  #: () -> Array[singleton(Riffer::Tool)]
  def tools
    @mutex.synchronize { @tools }
  end

  # Exception from failed tool discovery, or +nil+ if discovery succeeded or is still in progress.
  #
  #--
  #: () -> Exception?
  def discovery_error
    @mutex.synchronize { @discovery_error }
  end

  #--
  #: (Riffer::Mcp::Manifest) -> void
  def initialize(manifest)
    @manifest = manifest
    @ready = false
    @cancelled = false
    @tools = []
    @discovery_error = nil
    @discovery_thread = nil
    @mutex = Mutex.new
    spawn_discovery_thread
  end

  # Retires this registration, preventing the discovery thread from publishing
  # state and killing it if still running.
  #
  #--
  #: () -> void
  def retire!
    @mutex.synchronize { @cancelled = true }
    @discovery_thread&.kill
  end

  # Returns true once tool discovery has completed successfully.
  #
  #--
  #: () -> bool
  def ready?
    @mutex.synchronize { @ready }
  end

  # Returns true if this registration has been retired.
  #
  #--
  #: () -> bool
  def retired?
    @mutex.synchronize { @cancelled }
  end

  # Blocks the calling thread until this registration is ready or the timeout elapses.
  #
  # If tool discovery failed in the background thread, re-raises that exception
  # immediately (no wait for +wait_timeout+).
  #
  # Raises Riffer::Mcp::TimeoutError if discovery is still in progress and
  # +Riffer.config.mcp.wait_timeout+ seconds pass without becoming ready.
  #
  #--
  #: () -> void
  def wait_until_ready!
    deadline = Time.now + Riffer.config.mcp.wait_timeout
    loop do
      return if ready?
      err = discovery_error
      raise err if err
      raise Riffer::Mcp::TimeoutError, "MCP server '#{@manifest.name}' did not become ready within #{Riffer.config.mcp.wait_timeout}s" if Time.now >= deadline
      sleep 0.05
    end
  end

  private

  # Discovery is a one-shot background init task, not concurrent tool execution
  # during an agent run, so ToolRuntime does not apply. The factory is exposed
  # for environments where raw Thread.new has side effects (e.g. connection pool
  # inheritance in Rails).
  #
  #--
  #: () -> Thread
  def spawn_discovery_thread
    @discovery_thread = Riffer.config.mcp.discovery_thread_factory.call do
      client = build_client
      tool_defs = client.tools_list
      tools = Riffer::Mcp::ToolFactory.build(client, tool_defs)

      @mutex.synchronize do
        next if @cancelled
        @tools = tools.freeze
        @ready = true
      end
    rescue => e
      @mutex.synchronize do
        next if @cancelled
        @discovery_error = e
      end
      # Leave @ready = false — callers apply the on_pending strategy
    end
  end

  #--
  #: () -> Riffer::Mcp::Client
  def build_client
    Riffer::Mcp::Client.new(endpoint: @manifest.endpoint, headers: @manifest.discovery_headers || {})
  end
end
