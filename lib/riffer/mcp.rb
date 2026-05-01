# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Mcp provides integration with Model Context Protocol (MCP) servers.
#
# Register MCP servers globally; agents opt-in by tag via the +use_mcp+ DSL.
# Tags are application-defined; see +docs/14_MCP.md+ (Tags section).
#
#   Riffer::Mcp.register(
#     name: "github",
#     tags: [:github],
#     endpoint: "https://mcp.github.com",
#     discovery_headers: -> { {"Authorization" => "Bearer #{ENV['GITHUB_TOKEN']}"} }
#   )
#
#   class MyAgent < Riffer::Agent
#     model "openai/gpt-4o"
#     use_mcp :github
#   end
#
module Riffer::Mcp
  # Base error for all MCP-related failures.
  class Error < Riffer::Error; end

  # Raised when +Riffer.config.mcp.credentials+ returns +nil+ during +tools/call+
  # after the server's tools were included for this run.
  class CredentialsDeniedError < Error; end

  # Registers an MCP server, blocking until tool discovery completes.
  #
  # Raises on discovery failure. Pass a +Manifest+ instance or a hash with
  # the same keys.
  #
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Mcp::Manifest)) -> Riffer::Mcp::Registration
  def self.register(manifest_or_hash)
    Registry.register(manifest_or_hash)
  end

  # Removes a registration by name.
  #
  # Subsequent agent runs will not see tools from this server.
  #
  #--
  #: (String) -> void
  def self.unregister(name)
    Registry.unregister(name)
  end

  # Returns all current registrations keyed by name (for introspection).
  #
  #--
  #: () -> Hash[String, Riffer::Mcp::Registration]
  def self.registrations
    Registry.registrations
  end
end
