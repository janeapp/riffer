# frozen_string_literal: true
# rbs_inline: enabled

# Composes the +Riffer::McpServer+ Rack pipeline:
#
#   AuthMiddleware  →  ContextBridge  →  MCP::StreamableHTTPTransport
#
# The transport is configured for stateless + JSON-response delivery so
# clients can issue +tools/list+ / +tools/call+ requests without negotiating
# a session. Per-request riffer context flows in through the
# +ContextBridge+, which builds a fresh +MCP::Server+ each call (cheap;
# avoids racing on a shared mutable +server_context+).
class Riffer::McpServer::RackApp
  extend Riffer::Helpers::Dependencies

  # Builds and returns the composed Rack app.
  #
  #--
  #: (config: Riffer::McpServer::Config, registry: Riffer::McpServer::Registry) -> untyped
  def self.build(config:, registry:)
    depends_on "rack"
    depends_on "mcp"

    inner = ContextBridge.new(config: config, registry: registry)
    Riffer::McpServer::AuthMiddleware.new(inner, config: config)
  end

  # Inner middleware that translates an authenticated request into a
  # per-request +MCP::Server+ keyed by the riffer context built from the
  # token object.
  class ContextBridge
    #: (config: Riffer::McpServer::Config, registry: Riffer::McpServer::Registry) -> void
    def initialize(config:, registry:)
      @config = config
      @registry = registry
    end

    #: (Hash[String, untyped]) -> [Integer, Hash[String, String], untyped]
    def call(env)
      token_object = env[Riffer::McpServer::AuthMiddleware::TOKEN_ENV_KEY]
      riffer_context = @config.context_builder.call(token_object)
      adapters = build_adapters
      server = MCP::Server.new(
        name: @config.server_name,
        version: @config.server_version,
        tools: adapters,
        server_context: {riffer_context: riffer_context}
      )
      transport = MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        enable_json_response: true
      )
      transport.call(env)
    end

    private

    #: () -> Array[untyped]
    def build_adapters
      @registry.all.map { |record| Riffer::McpServer::ToolAdapter.build_for(record[:tool_class]) }
    end
  end
end
