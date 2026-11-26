# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::MarkdownAdapter < Riffer::Skills::Adapter
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

  #--
  #: (String) -> String
  def single_line(description)
    # A multi-line (block scalar) description must stay within its `-` list
    # item; continuation lines at column 0 would read as top-level prompt text
    # or fabricated catalog entries.
    description.gsub(/\s+/, " ").strip
  end
end
