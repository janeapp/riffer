# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::MarkdownAdapter < Riffer::Skills::Adapter
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
