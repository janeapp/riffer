# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Skills::ActivateTool < Riffer::Tool
  identifier "skill_activate"
  description "Activates a skill and returns its instructions. " \
              "Call this when a task matches an available skill's description."
  timeout 1

  params do
    required :name, String, description: "The skill name to activate"
  end

  #: (context: Hash[Symbol, untyped]?, name: String) -> Riffer::Tools::Response
  def call(context:, name:)
    skills_context = context&.dig(:skills)
    return error("Skills not configured") unless skills_context

    text(skills_context.activate(name))
  rescue Riffer::ArgumentError => e
    error(e.message)
  end
end
