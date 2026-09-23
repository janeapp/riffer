# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::Backend
  SKILL_FILENAME = "SKILL.md" #: String

  def initialize = nil

  #--
  #: () -> Array[Riffer::Skills::Frontmatter]
  def list_skills
    raise NotImplementedError, "#{self.class} must implement #list_skills"
  end

  # Returns the SKILL.md body without frontmatter. Raises Riffer::ArgumentError
  # if the skill is not found.
  #--
  #: (String) -> String
  def read_skill(name)
    raise NotImplementedError, "#{self.class} must implement #read_skill"
  end
end
