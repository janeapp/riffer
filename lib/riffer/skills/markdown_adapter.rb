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
    lines << catalog_instructions
    lines << ""
    skills.each do |skill|
      lines << "- **#{skill.name}**: #{skill.description}"
    end
    lines.join("\n")
  end
end
