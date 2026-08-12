# frozen_string_literal: true
# rbs_inline: enabled

# Integration with Model Context Protocol (MCP) servers. Register servers
# globally; agents opt-in by tag via the +use_mcp+ DSL. Tags are
# application-defined; see +docs/MCP.md+.
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
  extend self

  # Base error for all MCP-related failures.
  class Error < Riffer::Error; end

  # Raised when +Riffer.config.mcp.credentials+ returns +nil+ during +tools/call+
  # after the server's tools were included for this run.
  class CredentialsDeniedError < Error; end

  # Registers an MCP server, blocking until tool discovery completes. Raises
  # on discovery failure.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Mcp::Manifest)) -> Riffer::Mcp::Registration
  def register(manifest_or_hash)
    Registry.register(manifest_or_hash)
  end

  # Removes a registration by name; subsequent agent runs won't see its tools.
  #--
  #: (String) -> void
  def unregister(name)
    Registry.unregister(name)
  end

  # Returns all current registrations keyed by name.
  #
  #--
  #: () -> Hash[String, Riffer::Mcp::Registration]
  def registrations
    Registry.registrations
  end
end
