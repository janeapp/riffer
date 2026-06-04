# frozen_string_literal: true
# rbs_inline: enabled

require "uri"

# Holds the configuration for a single MCP server.
class Riffer::Mcp::Manifest
  # Identifier used as the registration key and generated-agent identifier.
  attr_reader :name #: String

  # Tags for matching +use_mcp+.
  attr_reader :tags #: Array[Symbol]

  # HTTPS URL passed to the MCP transport.
  attr_reader :endpoint #: String

  # Headers (or a Proc) resolved once when building the discovery client.
  attr_reader :discovery_headers #: (Hash[String, untyped] | ::Proc)?

  # Optional hint (+:global+/+:tenant+/+:user+) for whether invocation
  # credentials depend on tenant/user keys in +context+.
  attr_reader :credentials_scope #: Symbol?

  # Raises Riffer::ArgumentError unless +name+ is present and +endpoint+ is a
  # valid HTTPS URL.
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
