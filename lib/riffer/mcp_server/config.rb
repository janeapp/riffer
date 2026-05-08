# frozen_string_literal: true
# rbs_inline: enabled

# Holds the configuration for a +Riffer::McpServer+ instance.
#
# +authenticator+ is a Proc that receives the bearer token String and returns
# either an opaque token object (any object) or +nil+ to deny the request.
# +context_builder+ is a Proc that receives the token object and returns a
# Hash to use as the per-request riffer context. The default builder returns
# an empty Hash.
class Riffer::McpServer::Config
  DEFAULT_SERVER_NAME = "riffer-mcp-server" #: String
  DEFAULT_SERVER_VERSION = "1.0.0" #: String
  DEFAULT_CONTEXT_BUILDER = ->(_) { {} } #: ^(untyped) -> Hash[Symbol, untyped]

  attr_accessor :authenticator #: ^(String) -> untyped | nil
  attr_accessor :context_builder #: ^(untyped) -> Hash[Symbol, untyped]
  attr_accessor :server_name #: String
  attr_accessor :server_version #: String
  attr_reader :registry #: Riffer::McpServer::Registry

  #: (registry: Riffer::McpServer::Registry) -> void
  def initialize(registry:)
    @registry = registry
    @authenticator = nil
    @context_builder = DEFAULT_CONTEXT_BUILDER
    @server_name = DEFAULT_SERVER_NAME
    @server_version = DEFAULT_SERVER_VERSION
  end

  # Convenience for +configure+ blocks: registers the tool with the
  # underlying registry under the given scope.
  #
  #--
  #: (Class, ?scope: (Symbol | Array[Symbol])) -> Hash[Symbol, untyped]
  def expose(tool_class, scope: :default)
    @registry.register(tool_class, scope: scope)
  end
end
