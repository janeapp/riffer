# frozen_string_literal: true
# rbs_inline: enabled

# Skills context for an agent generation cycle.
#
# Coordinates skill discovery, activation, and prompt rendering.
# Tracks activations with caching to avoid redundant backend reads.
#
# Built by the agent at the start of generate/stream and passed to
# tools via +context[:skills]+.
#
# See Riffer::Skills::Backend, Riffer::Skills::Frontmatter.
class Riffer::Skills::Context
  # Skill catalog indexed by name.
  attr_reader :skills #: Hash[String, Riffer::Skills::Frontmatter]

  # The skill adapter used for this context.
  attr_reader :adapter #: Riffer::Skills::Adapter

  # Optional callback invoked when a skill is first activated.
  attr_writer :on_activate #: (^(String) -> void)?

  # Creates a new skills context for a generation cycle.
  #
  # [backend] the skills backend for reading skill bodies.
  # [skills] skill catalog indexed by name.
  # [adapter] the adapter used to render skill content. The adapter
  #           carries the activation tool class via its initializer.
  #
  #--
  #: (backend: Riffer::Skills::Backend, skills: Hash[String, Riffer::Skills::Frontmatter], adapter: Riffer::Skills::Adapter) -> void
  def initialize(backend:, skills:, adapter:)
    @backend = backend
    @skills = skills
    @adapter = adapter
    @activated = {} #: Hash[String, String]
  end

  # Activates a skill by name. Returns the cached body on re-activation.
  #
  # Raises Riffer::ArgumentError if the skill is not in the catalog.
  #
  #--
  #: (String) -> String
  def activate(name)
    raise Riffer::ArgumentError, "Unknown skill: '#{name}'" unless skills.key?(name)
    return @activated[name] if @activated.key?(name)
    @activated[name] = @backend.read_skill(name)
    @on_activate&.call(name)
    @activated[name]
  end

  # Returns whether a skill has been activated.
  #
  #--
  #: (String) -> bool
  def activated?(name)
    @activated.key?(name)
  end

  # Returns the complete skills section for the system prompt.
  #
  # Includes the catalog and any pre-activated skill bodies.
  #
  #--
  #: () -> String
  def system_prompt
    available = available_skills
    parts = []
    parts << @adapter.render_catalog(available) unless available.empty?
    @activated.each_value { |body| parts << body }
    parts.join("\n\n")
  end

  private

  #--
  #: () -> Array[Riffer::Skills::Frontmatter]
  def available_skills
    skills.values.reject { |skill| @activated.key?(skill.name) }
  end
end
