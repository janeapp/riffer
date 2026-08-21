# frozen_string_literal: true
# rbs_inline: enabled

# Built-in backend that reads skills from the filesystem. Scans configured
# directories for immediate child directories containing +SKILL.md+; directory
# names must match the skill +name+.
class Riffer::Skills::FilesystemBackend < Riffer::Skills::Backend
  # @rbs @paths: Array[String]
  # @rbs @skills_cache: Hash[String, String]?

  #--
  #: (*String) -> void
  def initialize(*paths)
    super()
    @paths = paths.flatten.map { |p| File.expand_path(p) }
    @skills_cache = nil #: Hash[String, String]?
  end

  # Returns frontmatter for all discovered skills; on a name collision across
  # paths, first-path-wins.
  #--
  #: () -> Array[Riffer::Skills::Frontmatter]
  def list_skills
    cache = {} #: Hash[String, String]
    @skills_cache = cache
    frontmatters = [] #: Array[Riffer::Skills::Frontmatter]

    @paths.each do |path|
      next unless File.directory?(path)

      Dir.children(path).sort.each do |dirname|
        dir = File.join(path, dirname)
        skill_file = File.join(dir, SKILL_FILENAME)
        next unless File.directory?(dir) && File.file?(skill_file)

        frontmatter = Riffer::Skills::Frontmatter.parse_frontmatter(File.read(skill_file))

        validate_dirname_matches_name!(dirname, frontmatter.name)
        next if cache.key?(frontmatter.name)

        frontmatters << frontmatter
        cache[frontmatter.name] = dir
      end
    end

    frontmatters
  end

  # Returns the full SKILL.md body (without frontmatter) for a skill. Raises
  # Riffer::ArgumentError if the skill is not found.
  #--
  #: (String) -> String
  def read_skill(name)
    list_skills unless @skills_cache
    cache = @skills_cache #: Hash[String, String]
    dir = cache[name]
    raise Riffer::ArgumentError, "Skill not found: '#{name}'" unless dir

    _, body = Riffer::Skills::Frontmatter.parse(File.read(File.join(dir, SKILL_FILENAME)))
    body
  end

  private

  #--
  #: (String, String) -> void
  def validate_dirname_matches_name!(dirname, name)
    return if dirname == name

    raise Riffer::ArgumentError, "Skill directory '#{dirname}' does not match name '#{name}'"
  end
end
