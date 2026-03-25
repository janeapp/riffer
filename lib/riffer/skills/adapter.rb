# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::Adapter
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    raise NotImplementedError, "#{self.class} must implement #render_catalog"
  end

  #: () -> singleton(Riffer::Tool)
  def activate_tool
    Riffer::Skills::ActivateTool
  end
end
