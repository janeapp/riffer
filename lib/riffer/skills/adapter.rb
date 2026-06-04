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
end
