# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Rack middleware that validates the +Authorization: Bearer ...+ header
# against the configured authenticator Proc and stashes the resolved token
# object in the rack env at +"riffer.mcp_server.token"+.
#
# Returns a JSON-RPC 2.0 error envelope with HTTP 401 on rejection. Raises
# +Riffer::McpServer::ConfigurationError+ when invoked without an
# authenticator configured — that is a programmer error, not a request
# error.
class Riffer::McpServer::AuthMiddleware
  TOKEN_ENV_KEY = "riffer.mcp_server.token" #: String
  BEARER_PREFIX = "Bearer " #: String
  PARSE_ERROR_CODE = -32_000 #: Integer

  #: (untyped, config: Riffer::McpServer::Config) -> void
  def initialize(app, config:)
    @app = app
    @config = config
  end

  #: (Hash[String, untyped]) -> [Integer, Hash[String, String], Array[String]]
  def call(env)
    authenticator = @config.authenticator
    raise Riffer::McpServer::ConfigurationError, "Riffer::McpServer requires an authenticator to be configured" if authenticator.nil?

    header = env["HTTP_AUTHORIZATION"]
    return unauthorized("Missing Authorization header") unless header.is_a?(String) && header.start_with?(BEARER_PREFIX)

    token = header.delete_prefix(BEARER_PREFIX).strip
    return unauthorized("Missing bearer token") if token.empty?

    token_object = begin
      authenticator.call(token)
    rescue
      nil
    end

    return unauthorized("Invalid bearer token") if token_object.nil?

    env[TOKEN_ENV_KEY] = token_object
    @app.call(env)
  end

  private

  #: (String) -> [Integer, Hash[String, String], Array[String]]
  def unauthorized(message)
    body = {jsonrpc: "2.0", error: {code: PARSE_ERROR_CODE, message: message}, id: nil}
    [401, {"Content-Type" => "application/json"}, [JSON.generate(body)]]
  end
end
