# frozen_string_literal: true
# rbs_inline: enabled

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
    unless value.nil? || value.respond_to?(:call)
      raise Riffer::ArgumentError, "credentials must respond to #call or be nil"
    end

    @credentials = value
  end

  #--
  #: (untyped) -> void
  def discovery_runner=(value)
    @discovery_runner = Riffer::Helpers::Validate.runner(value, attribute: "discovery_runner")
  end
end
