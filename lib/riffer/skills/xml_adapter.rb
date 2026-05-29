# frozen_string_literal: true
# rbs_inline: enabled

require "cgi"

# XML skill adapter, optimized for Anthropic/Claude.
#
# Renders a skill catalog as XML for the system prompt.
#
# See Riffer::Skills::MarkdownAdapter for the default variant.
class Riffer::Skills::XmlAdapter < Riffer::Skills::Adapter
  # Renders a skill catalog as XML.
  #
  # [skills] array of Frontmatter objects to render.
  #
  #--
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    lines = [] #: Array[String]
    lines << "When a user's request matches a skill description below, call the `#{skill_activate_tool.name}` tool with the skill name. After activation, follow the skill's instructions."
    lines << ""
    lines << "<available_skills>"
    skills.each do |skill|
      lines << "  <skill>"
      lines << "    <name>#{CGI.escapeHTML(skill.name)}</name>"
      lines << "    <description>#{CGI.escapeHTML(skill.description)}</description>"
      lines << "  </skill>"
    end
    lines << "</available_skills>"
    lines.join("\n")
  end
end
