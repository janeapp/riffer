# frozen_string_literal: true
# rbs_inline: enabled

require "uri"

# Riffer::Mcp::Manifest holds the configuration for a single MCP server.
#
# +name+                - String identifier used as the registration key and generated-agent identifier.
# +tags+                - Array[Symbol]; normalized to symbols at construction time.
# +endpoint+            - String HTTPS URL passed to the MCP transport.
# +discovery_headers+   - Hash or Proc; resolved once when building the discovery client for +tools/list+.
# +credentials_scope+  - Optional symbol hint: +:global+, +:tenant+, +:user+ — documents whether
#   invocation credentials are expected to depend on tenant and/or user keys in +context+ (no ids stored).
#   Apps may treat +:user+ as "user in tenant" and pass both keys in +context+.
#
class Riffer::Mcp::Manifest
  attr_reader :name #: String
  attr_reader :tags #: Array[Symbol]
  attr_reader :endpoint #: String
  attr_reader :discovery_headers #: (Hash[String, untyped] | ::Proc)?
  attr_reader :credentials_scope #: Symbol?

  #--
  #: (name: String, endpoint: String, ?tags: Array[untyped]?, ?discovery_headers: (Hash[String, untyped] | ::Proc)?, ?credentials_scope: (String | Symbol)?) -> void
  def initialize(name:, endpoint:, tags: nil, discovery_headers: nil, credentials_scope: nil)
    @name = name.to_s.strip
    raise Riffer::ArgumentError, "MCP manifest name is required" if @name.empty?

    @endpoint = endpoint.to_s.strip
    raise Riffer::ArgumentError, "MCP manifest endpoint must be a valid HTTPS URL" unless valid_endpoint?

    @tags = Array(tags).map(&:to_sym)
    @discovery_headers = discovery_headers
    @credentials_scope = credentials_scope&.to_sym
  end

  private

  def valid_endpoint?
    uri = URI.parse(@endpoint)
    uri.is_a?(URI::HTTPS) && uri.host
  rescue URI::InvalidURIError
    false
  end
end
