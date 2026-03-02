# frozen_string_literal: true
# rbs_inline: enabled

# Base class defining the interface for skill storage backends.
#
# Subclass and implement +list_skills+ and +read_skill+ to provide
# custom skill storage (database, S3, etc.).
#
# Use Riffer::Skills::Frontmatter.parse to parse raw SKILL.md content.
#
# See Riffer::Skills::FilesystemBackend for the built-in implementation.
class Riffer::Skills::Backend
  SKILL_FILENAME = "SKILL.md" #: String

  # Returns frontmatter for all available skills.
  #
  # Called once at the start of generate/stream.
  #
  # Raises NotImplementedError if not implemented by subclass.
  #
  #: () -> Array[Riffer::Skills::Frontmatter]
  def list_skills
    raise NotImplementedError, "#{self.class} must implement #list_skills"
  end

  # Returns the full SKILL.md body (without frontmatter) for a skill.
  #
  # +name+ - the skill name to read.
  #
  # Raises NotImplementedError if not implemented by subclass.
  # Raises Riffer::ArgumentError if skill not found.
  #
  #: (String) -> String
  def read_skill(name)
    raise NotImplementedError, "#{self.class} must implement #read_skill"
  end
end
