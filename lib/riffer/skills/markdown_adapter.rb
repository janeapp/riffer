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
      lines << "- **#{skill.name}**: #{single_line(skill.description)}"
    end
    lines.join("\n")
  end

  private

  # Collapses whitespace so a multi-line (block scalar) description stays within
  # its `-` list item instead of breaking out to column 0, where continuation
  # lines would read as top-level prompt text or fabricated catalog entries.
  #--
  #: (String) -> String
  def single_line(description)
    description.gsub(/\s+/, " ").strip
  end
end
