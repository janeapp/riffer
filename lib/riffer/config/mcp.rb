# frozen_string_literal: true
# rbs_inline: enabled

# @deprecated MCP client support will be removed; wrap the +mcp+ gem in your own Riffer::Tool (see docs/MCP.md).
class Riffer::Config::Mcp
  attr_reader :credentials #: untyped # @dynamic credentials

  attr_reader :discovery_runner #: Riffer::Runner # @dynamic discovery_runner

  #--
  #: () -> void
  def initialize
    @credentials = nil
    @discovery_runner = Riffer::Runner::Sequential.new
  end

  #--
  #: (untyped) -> void
  def credentials=(value)
    warn_deprecated

    unless value.nil? || value.respond_to?(:call)
      raise Riffer::ArgumentError, "credentials must respond to #call or be nil"
    end

    @credentials = value
  end

  #--
  #: (untyped) -> void
  def discovery_runner=(value)
    warn_deprecated

    @discovery_runner = Riffer::Helpers::Validate.runner(value, attribute: "discovery_runner")
  end

  private

  #--
  #: () -> void
  def warn_deprecated
    Riffer::Deprecation.warn(
      id: :config_mcp,
      message: "config.mcp is deprecated; MCP client support will be removed in a future release. " \
               "Wrap the mcp gem in your own Riffer::Tool instead (see docs/MCP.md).",
    )
  end
end
