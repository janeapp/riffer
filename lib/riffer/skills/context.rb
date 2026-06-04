# frozen_string_literal: true
# rbs_inline: enabled

# Skills context for an agent generation cycle — coordinates discovery,
# activation, and prompt rendering, caching activations to avoid redundant
# backend reads. Exposed to tools via <tt>context.skills</tt>.
class Riffer::Skills::Context
  # @rbs @backend: Riffer::Skills::Backend
  # @rbs @activated: Hash[String, String]

  # Skill catalog indexed by name.
  attr_reader :skills #: Hash[String, Riffer::Skills::Frontmatter]

  # The skill adapter used for this context.
  attr_reader :adapter #: Riffer::Skills::Adapter

  # Optional callback invoked when a skill is first activated.
  attr_writer :on_activate #: (^(String) -> void)?

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

  # Returns the complete skills section for the system prompt — the catalog plus
  # any pre-activated skill bodies.
  #--
  #: () -> String
  def system_prompt
    available = available_skills
    parts = [] #: Array[String]
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
