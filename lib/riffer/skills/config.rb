# frozen_string_literal: true
# rbs_inline: enabled

# Configuration object for the skills block DSL.
#
#   skills do
#     backend Riffer::Skills::FilesystemBackend.new(".skills")
#     adapter Riffer::Skills::XmlAdapter
#     activate ["code-review"]
#   end
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

  # Gets or sets the skills backend (a Backend or a +context+-resolved Proc).
  #--
  #: (?(Riffer::Skills::Backend | Proc)?) -> (Riffer::Skills::Backend | Proc)?
  def backend(value = nil)
    return @backend if value.nil?
    @backend = value
  end

  # Gets or sets a custom skill adapter class; defaults to the provider's
  # preferred adapter.
  #--
  #: (?singleton(Riffer::Skills::Adapter)?) -> singleton(Riffer::Skills::Adapter)?
  def adapter(value = nil)
    return @adapter if value.nil?
    @adapter = value
  end

  # Gets or sets skill names to activate at startup (an array or a
  # +context+-resolved Proc); activated skills' bodies are included in the
  # system prompt without a tool call.
  #--
  #: (?(Array[String] | Proc)?) -> (Array[String] | Proc)?
  def activate(value = nil)
    return @activate if value.nil?
    @activate = value
  end

  # Gets or sets the per-agent skill activation tool override, or +nil+ when
  # unset — the global fallback to <tt>Riffer.config.skills.default_activate_tool</tt>
  # is applied by the agent at resolution, not here. Raises Riffer::ArgumentError
  # on an invalid value.
  #--
  #: (?singleton(Riffer::Tool)?) -> singleton(Riffer::Tool)?
  def activate_tool(value = nil)
    return @activate_tool if value.nil?
    raise Riffer::ArgumentError, "activate_tool must be a Riffer::Tool subclass" unless value.is_a?(Class) && value < Riffer::Tool
    @activate_tool = value
  end
end
