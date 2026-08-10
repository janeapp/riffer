# frozen_string_literal: true
# rbs_inline: enabled

# Interface for skill adapters — provider-specific rendering of the
# available-skills section in the system prompt. Subclass and override
# +render_catalog+; the activation tool is exposed via +#skill_activate_tool+
# for the rendered output.
class Riffer::Skills::Adapter
  # The activation tool class for this adapter.
  attr_reader :skill_activate_tool #: singleton(Riffer::Tool)

  #--
  #: (skill_activate_tool: singleton(Riffer::Tool)) -> void
  def initialize(skill_activate_tool:)
    @skill_activate_tool = skill_activate_tool
  end

  # Renders a skill catalog section for the system prompt.
  #--
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    raise NotImplementedError, "#{self.class} must implement #render_catalog"
  end

  # Renders an activated skill body wrapped in identifying tags.
  #--
  #: (Riffer::Skills::Frontmatter, String) -> String
  def render_activation(skill, body)
    %(<skill_content name="#{skill.name}">\n#{body}\n</skill_content>)
  end

  # The behavioral instructions rendered alongside the catalog.
  #--
  #: () -> String
  def catalog_instructions
    "When a user's request matches a skill description below, call the `#{skill_activate_tool.name}` tool " \
      "with the skill name. After activation, follow the skill's instructions. " \
      "If a skill's instructions already appear in your context (inside <skill_content> tags), " \
      "follow them instead of activating the skill again."
  end
end
