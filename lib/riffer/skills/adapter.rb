# frozen_string_literal: true
# rbs_inline: enabled

# Base class defining the interface for skill adapters.
#
# A skill adapter encapsulates the provider-specific behavior for skills:
# how the skill catalog is rendered in the system prompt, and which tool
# the LLM calls to activate a skill.
#
# Subclass and override +render_catalog+ and optionally +activate_tool+
# to customize behavior.
#
# See Riffer::Skills::MarkdownAdapter for the default implementation.
# See Riffer::Skills::XmlAdapter for the Anthropic/Claude variant.
class Riffer::Skills::Adapter
  # Renders a skill catalog section for the system prompt.
  #
  # [skills] array of Frontmatter objects to render.
  #
  # Raises NotImplementedError if not implemented by subclass.
  #
  #--
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    raise NotImplementedError, "#{self.class} must implement #render_catalog"
  end

  # Returns the tool class used to activate skills.
  #
  # Override to provide a custom activation tool.
  #
  #--
  #: () -> singleton(Riffer::Tool)
  def activate_tool
    Riffer::Skills::ActivateTool
  end
end
