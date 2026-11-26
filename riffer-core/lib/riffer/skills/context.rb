# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::Context
  # @rbs @backend: Riffer::Skills::Backend
  # @rbs @bodies: Hash[String, String]
  # @rbs @activated: Array[String]
  # @rbs @preactivated: Array[String]

  attr_reader :skills #: Hash[String, Riffer::Skills::Frontmatter] # @dynamic skills

  attr_reader :adapter #: Riffer::Skills::Adapter # @dynamic adapter

  attr_accessor :on_activate #: (^(String) -> void)? # @dynamic on_activate, on_activate=

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

  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #--
  #: (String) -> String
  def read(name)
    raise Riffer::ArgumentError, "Unknown skill: '#{name}'" unless skills.key?(name)

    @bodies[name] ||= @backend.read_skill(name)
  end

  # Raises Riffer::ArgumentError if the skill is not in the catalog.
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

  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #--
  #: (String) -> String
  def activation_prompt(name)
    body = activate(name)
    @adapter.render_activation(skills.fetch(name), body)
  end

  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #--
  #: (String) -> void
  def preactivate(name)
    activate(name)
    @preactivated << name unless @preactivated.include?(name)
  end

  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #--
  #: (String) -> void
  def deactivate(name)
    raise Riffer::ArgumentError, "Unknown skill: '#{name}'" unless skills.key?(name)

    @activated.delete(name)
    nil
  end

  #--
  #: (String) -> bool
  def activated?(name)
    @activated.include?(name)
  end

  #--
  #: (String) -> bool
  def model_invocable?(name)
    skills.key?(name) && !skills.fetch(name).disable_model_invocation
  end

  #--
  #: () -> bool
  def activatable?
    available_skills.any?
  end

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
