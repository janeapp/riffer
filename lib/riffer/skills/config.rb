# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::Config
  # @rbs @backend: (Riffer::Skills::Backend | Proc)?
  # @rbs @adapter: singleton(Riffer::Skills::Adapter)?
  # @rbs @activate: (Array[String] | Proc)?
  # @rbs @activate_tool: singleton(Riffer::Tool)?

  #--
  #: () -> void
  def initialize
    @backend = nil
    @adapter = nil
    @activate = nil
    @activate_tool = nil
  end

  #--
  #: (?(Riffer::Skills::Backend | Proc)?) -> (Riffer::Skills::Backend | Proc)?
  def backend(value = nil)
    return @backend if value.nil?

    @backend = value
  end

  #--
  #: (?singleton(Riffer::Skills::Adapter)?) -> singleton(Riffer::Skills::Adapter)?
  def adapter(value = nil)
    return @adapter if value.nil?

    @adapter = value
  end

  #--
  #: (?(Array[String] | Proc)?) -> (Array[String] | Proc)?
  def activate(value = nil)
    return @activate if value.nil?

    @activate = value
  end

  #--
  #: (?singleton(Riffer::Tool)?) -> singleton(Riffer::Tool)?
  def activate_tool(value = nil)
    # No fallback to <tt>Riffer.config.skills.default_activate_tool</tt> here;
    # the agent applies it at resolution.
    return @activate_tool if value.nil?
    unless value.is_a?(Class) && value < Riffer::Tool
      raise Riffer::ArgumentError, "activate_tool must be a Riffer::Tool subclass"
    end

    @activate_tool = value
  end

  private

  #--
  #: (Riffer::Skills::Config) -> void
  def initialize_copy(source)
    super
    # A shallow copy would share the activation list, so activating a skill on
    # either config would reach the other.
    @activate = Riffer::Helpers::DeepDup.call(source.activate)
  end
end
