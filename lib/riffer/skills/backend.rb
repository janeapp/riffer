# frozen_string_literal: true
# rbs_inline: enabled

# Interface for skill storage backends. Subclass and implement +list_skills+
# and +read_skill+ for custom storage (database, S3, etc.); use
# Riffer::Skills::Frontmatter.parse on raw SKILL.md content.
class Riffer::Skills::Backend
  SKILL_FILENAME = "SKILL.md" #: String

  def initialize = nil

  # Returns frontmatter for all available skills; called once at the start of
  # generate/stream.
  #--
  #: () -> Array[Riffer::Skills::Frontmatter]
  def list_skills
    raise NotImplementedError, "#{self.class} must implement #list_skills"
  end

  # Returns the full SKILL.md body (without frontmatter) for a skill. Raises
  # Riffer::ArgumentError if the skill is not found.
  #--
  #: (String) -> String
  def read_skill(name)
    raise NotImplementedError, "#{self.class} must implement #read_skill"
  end
end
