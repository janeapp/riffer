# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::FilesystemBackend < Riffer::Skills::Backend
  #: (*String) -> void
  def initialize(*paths)
    @paths = paths.flatten.map { |p| File.expand_path(p) }
    @skills_cache = nil #: Hash[String, String]?
  end

  #: () -> Array[Riffer::Skills::Frontmatter]
  def list_skills
    @skills_cache = {}
    frontmatters = []

    @paths.each do |path|
      next unless File.directory?(path)

      Dir.children(path).sort.each do |dirname|
        dir = File.join(path, dirname)
        skill_file = File.join(dir, SKILL_FILENAME)
        next unless File.directory?(dir) && File.file?(skill_file)

        frontmatter = Riffer::Skills::Frontmatter.parse_frontmatter(File.read(skill_file))

        validate_dirname_matches_name!(dirname, frontmatter.name)
        next if @skills_cache.key?(frontmatter.name)

        frontmatters << frontmatter
        @skills_cache[frontmatter.name] = dir
      end
    end

    frontmatters
  end

  #: (String) -> String
  def read_skill(name)
    list_skills unless @skills_cache
    dir = @skills_cache[name]
    raise Riffer::ArgumentError, "Skill not found: '#{name}'" unless dir

    _, body = Riffer::Skills::Frontmatter.parse(File.read(File.join(dir, SKILL_FILENAME)))
    body
  end

  private

  #: (String, String) -> void
  def validate_dirname_matches_name!(dirname, name)
    return if dirname == name
    raise Riffer::ArgumentError, "Skill directory '#{dirname}' does not match name '#{name}'"
  end
end
