# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Config::Skills
  attr_reader :default_activate_tool #: singleton(Riffer::Tool) # @dynamic default_activate_tool

  attr_reader :default_backend #: (Riffer::Skills::Backend | Proc)? # @dynamic default_backend

  #--
  #: () -> void
  def initialize
    @default_activate_tool = Riffer::Skills::ActivateTool
    @default_backend = nil
  end

  #--
  #: (singleton(Riffer::Tool)) -> void
  def default_activate_tool=(value)
    unless value.is_a?(Class) && value < Riffer::Tool
      raise Riffer::ArgumentError,
            "default_activate_tool must be a Riffer::Tool subclass"
    end

    @default_activate_tool = value
  end

  #--
  #: ((Riffer::Skills::Backend | Proc)?) -> void
  def default_backend=(value)
    valid = value.nil? || value.is_a?(Riffer::Skills::Backend) || value.is_a?(Proc)
    unless valid
      raise Riffer::ArgumentError,
            "default_backend must be a Riffer::Skills::Backend instance, Proc, or nil"
    end

    @default_backend = value
  end
end
