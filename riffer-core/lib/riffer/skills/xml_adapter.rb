# frozen_string_literal: true
# rbs_inline: enabled

require "cgi/escape"

class Riffer::Skills::XmlAdapter < Riffer::Skills::Adapter
  #--
  #: (Array[Riffer::Skills::Frontmatter]) -> String
  def render_catalog(skills)
    lines = [] #: Array[String]
    lines << catalog_instructions
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
