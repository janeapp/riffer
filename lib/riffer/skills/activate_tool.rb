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

  #--
  #: (context: Riffer::Agent::Context?, name: String) -> Riffer::Tools::Response
  def call(context:, name:)
    skills_context = context&.skills
    return error("Skills not configured") unless skills_context
    return error("Unknown skill: '#{name}'") unless skills_context.model_invocable?(name)
    return text(already_active_message(name)) if skills_context.activated?(name)

    text(skills_context.activation_prompt(name))
  rescue Riffer::ArgumentError => e
    error(e.message)
  end

  private

  #--
  #: (String) -> String
  def already_active_message(name)
    "Skill '#{name}' is already active. Its instructions are already available in your context."
  end
end
