# frozen_string_literal: true
# rbs_inline: enabled

# Skills context for an agent generation cycle — coordinates discovery,
# activation, and prompt rendering, caching skill bodies to avoid redundant
# backend reads. Exposed to tools via <tt>context.skills</tt>.
class Riffer::Skills::Context
  # @rbs @backend: Riffer::Skills::Backend
  # @rbs @bodies: Hash[String, String]
  # @rbs @activated: Array[String]
  # @rbs @preactivated: Array[String]

  # Skill catalog indexed by name.
  attr_reader :skills #: Hash[String, Riffer::Skills::Frontmatter]

  # The skill adapter used for this context.
  attr_reader :adapter #: Riffer::Skills::Adapter

  # Optional callback invoked when a skill is first activated.
  attr_accessor :on_activate #: (^(String) -> void)?

  #--
  #: (backend: Riffer::Skills::Backend, skills: Hash[String, Riffer::Skills::Frontmatter], adapter: Riffer::Skills::Adapter) -> void
  def initialize(backend:, skills:, adapter:)
    @backend = backend
    @skills = skills
    @adapter = adapter
    @bodies = {} #: Hash[String, String]
    @activated = [] #: Array[String]
    @preactivated = [] #: Array[String]
  end

  # Returns a skill's body without recording an activation.
  #
  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #
  #--
  #: (String) -> String
  def read(name)
    raise Riffer::ArgumentError, "Unknown skill: '#{name}'" unless skills.key?(name)

    @bodies[name] ||= @backend.read_skill(name)
  end

  # Activates a skill by name. Returns the cached body on re-activation.
  #
  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #
  #--
  #: (String) -> String
  def activate(name)
    body = read(name)
    unless @activated.include?(name)
      @activated << name
      @on_activate&.call(name)
    end
    body
  end

  # Activates a skill and returns its body wrapped for injection as a user
  # message.
  #
  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #
  #--
  #: (String) -> String
  def activation_prompt(name)
    body = activate(name)
    @adapter.render_activation(skills.fetch(name), body)
  end

  # Activates a skill whose body renders in the system prompt rather than the
  # conversation.
  #
  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #
  #--
  #: (String) -> void
  def preactivate(name)
    activate(name)
    @preactivated << name unless @preactivated.include?(name)
  end

  # Clears a skill's activation so the next activation is treated as the first.
  #
  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #
  #--
  #: (String) -> void
  def deactivate(name)
    raise Riffer::ArgumentError, "Unknown skill: '#{name}'" unless skills.key?(name)

    @activated.delete(name)
    nil
  end

  # Returns whether a skill has been activated.
  #
  #--
  #: (String) -> bool
  def activated?(name)
    @activated.include?(name)
  end

  # Returns whether a skill exists and may be activated by the model.
  #--
  #: (String) -> bool
  def model_invocable?(name)
    skill = skills[name]
    return false unless skill

    !skill.disable_model_invocation
  end

  # Returns whether any skill is available for the model to activate.
  #--
  #: () -> bool
  def activatable?
    available_skills.any?
  end

  # Returns the complete skills section for the system prompt — the catalog plus
  # any pre-activated skill bodies.
  #--
  #: () -> String
  def system_prompt
    available = available_skills
    parts = [] #: Array[String]
    parts << @adapter.render_catalog(available) unless available.empty?
    @preactivated.each { |name| parts << @adapter.render_activation(skills.fetch(name), @bodies.fetch(name)) }
    parts.join("\n\n")
  end

  private

  #--
  #: () -> Array[Riffer::Skills::Frontmatter]
  def available_skills
    skills.values.reject { |skill| @preactivated.include?(skill.name) || skill.disable_model_invocation }
  end
end
