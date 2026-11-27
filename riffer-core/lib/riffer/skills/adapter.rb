# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::Adapter
  attr_reader :skill_activate_tool #: singleton(Riffer::Tool) # @dynamic skill_activate_tool

  #--
  #: (skill_activate_tool: singleton(Riffer::Tool)) -> void
  def initialize(skill_activate_tool:)
    @skill_activate_tool = skill_activate_tool
  end

  #--
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    raise NotImplementedError, "#{self.class} must implement #render_catalog"
  end

  #--
  #: (Riffer::Skills::Frontmatter, String) -> String
  def render_activation(skill, body)
    %(<skill_content name="#{skill.name}">\n#{body}\n</skill_content>)
  end

  #--
  #: () -> String
  def catalog_instructions
    "When a user's request matches a skill description below, call the `#{skill_activate_tool.name}` tool " \
      "with the skill name. After activation, follow the skill's instructions. " \
      "If a skill's instructions already appear in your context (inside <skill_content> tags), " \
      "follow them instead of activating the skill again."
  end
end
