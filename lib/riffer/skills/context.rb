# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::Context
  attr_reader :skills #: Hash[String, Riffer::Skills::Frontmatter]
  attr_reader :adapter #: Riffer::Skills::Adapter
  attr_writer :on_activate #: (^(String) -> void)?

  #: (backend: Riffer::Skills::Backend, skills: Hash[String, Riffer::Skills::Frontmatter], adapter: Riffer::Skills::Adapter) -> void
  def initialize(backend:, skills:, adapter:)
    @backend = backend
    @skills = skills
    @adapter = adapter
    @activated = {} #: Hash[String, String]
  end

  #: (String) -> String
  def activate(name)
    raise Riffer::ArgumentError, "Unknown skill: '#{name}'" unless skills.key?(name)
    return @activated[name] if @activated.key?(name)
    @activated[name] = @backend.read_skill(name)
    @on_activate&.call(name)
    @activated[name]
  end

  #: (String) -> bool
  def activated?(name)
    @activated.key?(name)
  end

  #: () -> String
  def system_prompt
    available = available_skills
    parts = []
    parts << @adapter.render_catalog(available) unless available.empty?
    @activated.each_value { |body| parts << body }
    parts.join("\n\n")
  end

  private

  #: () -> Array[Riffer::Skills::Frontmatter]
  def available_skills
    skills.values.reject { |skill| @activated.key?(skill.name) }
  end
end
