# frozen_string_literal: true
# rbs_inline: enabled

# Tool for the LLM to activate a skill and receive its full instructions.
#
# Registered automatically when an agent has skills configured.
# The LLM calls this when a task matches an available skill's description.
#
# See Riffer::Skills::Context.
class Riffer::Skills::ActivateTool < Riffer::Tool
  identifier "skill_activate"
  description "Activates a skill and returns its instructions. " \
              "Call this when a task matches an available skill's description."
  timeout 1

  params do
    required :name, String, description: "The skill name to activate"
  end

  # Activates a skill by name and returns its body.
  #
  # [context] tool context containing +:skills+ (a Riffer::Skills::Context).
  # [name] the skill name to activate.
  #
  #--
  #: (context: Hash[Symbol, untyped]?, name: String) -> Riffer::Tools::Response
  def call(context:, name:)
    skills_context = context&.dig(:skills)
    return error("Skills not configured") unless skills_context

    if skills_context.activated?(name)
      return text("Skill '#{name}' is already active; its instructions are already in your context.")
    end

    text(skills_context.activate(name))
  rescue Riffer::ArgumentError => e
    error(e.message)
  end
end
