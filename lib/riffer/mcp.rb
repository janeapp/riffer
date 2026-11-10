# frozen_string_literal: true
# rbs_inline: enabled

# @deprecated MCP client support will be removed; wrap the +mcp+ gem in your own Riffer::Tool (see docs/MCP.md).
module Riffer::Mcp
  extend self

  class Error < Riffer::Error; end

  # Raised when +Riffer.config.mcp.credentials+ returns +nil+ during +tools/call+
  # after the server's tools were already included for this run.
  class CredentialsDeniedError < Error; end

  # Blocks until tool discovery completes.
  #--
  #: ((Hash[Symbol, untyped] | Riffer::Mcp::Manifest)) -> Riffer::Mcp::Registration
  def register(manifest_or_hash)
    Riffer::Deprecation.warn(
      id: :mcp_register,
      message: "Riffer::Mcp.register is deprecated; MCP client support will be removed in a future release. " \
               "Wrap the mcp gem in your own Riffer::Tool instead (see docs/MCP.md).",
    )

    Registry.register(manifest_or_hash)
  end

  #--
  #: (String) -> void
  def unregister(name)
    Registry.unregister(name)
  end

  #--
  #: () -> Hash[String, Riffer::Mcp::Registration]
  def registrations
    Registry.registrations
  end
end
