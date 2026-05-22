# frozen_string_literal: true
# rbs_inline: enabled

# Configuration object for the skills block DSL.
#
# Used inside the +skills+ block on Riffer::Agent:
#
#   skills do
#     backend Riffer::Skills::FilesystemBackend.new(".skills")
#     adapter Riffer::Skills::XmlAdapter
#     activate ["code-review"]
#   end
class Riffer::Skills::Config
  # Creates a new Config with all options unset.
  #
  #--
  #: () -> void
  def initialize
    @backend = nil
    @adapter = nil
    @activate = nil
    @activate_tool = nil
  end

  # Gets or sets the skills backend.
  #
  # Accepts a Riffer::Skills::Backend instance, or a Proc that receives
  # +context+ and returns a Backend.
  #
  #--
  #: (?(Riffer::Skills::Backend | Proc)?) -> (Riffer::Skills::Backend | Proc)?
  def backend(value = nil)
    return @backend if value.nil?
    @backend = value
  end

  # Gets or sets a custom skill adapter class.
  #
  # Must be a subclass of Riffer::Skills::Adapter.
  # Defaults to the provider's preferred adapter.
  #
  #--
  #: (?singleton(Riffer::Skills::Adapter)?) -> singleton(Riffer::Skills::Adapter)?
  def adapter(value = nil)
    return @adapter if value.nil?
    @adapter = value
  end

  # Gets or sets skill names to activate at startup.
  #
  # Activated skills have their full body included in the system prompt
  # without requiring a tool call.
  #
  # Accepts an array of skill name strings or a Proc that receives
  # +context+ and returns an array of names.
  #
  #--
  #: (?(Array[String] | Proc)?) -> (Array[String] | Proc)?
  def activate(value = nil)
    return @activate if value.nil?
    @activate = value
  end

  # Gets or sets the per-agent override for the skill activation tool class.
  #
  # Returns the configured override when set, or +nil+ when unset. The
  # global fallback to <tt>Riffer.config.skills.default_activate_tool</tt>
  # is applied by the agent at resolution time (see
  # Riffer::Agent#resolve_tools), not by this getter.
  #
  # The override must be a subclass of Riffer::Tool.
  #
  #--
  #: (?singleton(Riffer::Tool)?) -> singleton(Riffer::Tool)?
  def activate_tool(value = nil)
    return @activate_tool if value.nil?
    raise Riffer::ArgumentError, "activate_tool must be a Riffer::Tool subclass" unless value.is_a?(Class) && value < Riffer::Tool
    @activate_tool = value
  end
end
