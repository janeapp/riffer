# frozen_string_literal: true
# rbs_inline: enabled

# Default skill adapter — renders a skill catalog as Markdown for the system
# prompt.
class Riffer::Skills::MarkdownAdapter < Riffer::Skills::Adapter
  # Renders a skill catalog as Markdown.
  #--
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    lines = [] #: Array[String]
    lines << "## Available Skills"
    lines << ""
    lines << "When a user's request matches a skill description below, call the `#{skill_activate_tool.name}` tool with the skill name. After activation, follow the skill's instructions."
    lines << ""
    skills.each do |skill|
      lines << "- **#{skill.name}**: #{skill.description}"
    end
    lines.join("\n")
  end
end
