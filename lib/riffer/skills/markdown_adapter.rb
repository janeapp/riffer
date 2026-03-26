# frozen_string_literal: true
# rbs_inline: enabled

# Default Markdown skill adapter.
#
# Renders a skill catalog as Markdown for the system prompt.
# Used by OpenAI, Amazon Bedrock, and other providers.
#
# See Riffer::Skills::XmlAdapter for the Anthropic/Claude variant.
class Riffer::Skills::MarkdownAdapter < Riffer::Skills::Adapter
  # Renders a skill catalog as Markdown.
  #
  # [skills] array of Frontmatter objects to render.
  #
  #--
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    lines = []
    lines << "## Available Skills"
    lines << ""
    lines << "When a user's request matches a skill description below, call the `#{activate_tool.name}` tool with the skill name. After activation, follow the skill's instructions."
    lines << ""
    skills.each do |skill|
      lines << "- **#{skill.name}**: #{skill.description}"
    end
    lines.join("\n")
  end
end
