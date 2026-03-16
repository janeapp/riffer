# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::AgentTool generates schema-only Riffer::Tool subclasses so
# the LLM sees subagents in its tool list.
#
# The generated tool's +call+ method is never invoked —
# Riffer::AgentRuntime handles dispatch directly.
#
#   tool_class = Riffer::AgentTool.build(MySubAgent)
#   tool_class.name          # => "agent__my_sub_agent"
#   tool_class.description   # => "Delegates to MySubAgent"
#
module Riffer::AgentTool
  AGENT_PREFIX = "agent__" #: String

  # Returns the tool identifier that would be generated for +agent_class+.
  #
  #: (singleton(Riffer::Agent)) -> String
  def self.identifier_for(agent_class)
    "#{AGENT_PREFIX}#{agent_class.identifier.gsub("/", "__")}"
  end

  # Builds a Riffer::Tool subclass for the given agent class.
  #
  # Raises Riffer::ArgumentError if the agent has no description.
  #
  #: (singleton(Riffer::Agent)) -> singleton(Riffer::Tool)
  def self.build(agent_class)
    raise Riffer::ArgumentError, "Agent #{agent_class} must have a description to be used as a subagent" unless agent_class.description

    tool_id = identifier_for(agent_class)
    agent_desc = agent_class.description

    Class.new(Riffer::Tool) do
      identifier tool_id
      description agent_desc

      params do
        required :message, String, description: "The message to send to the agent"
      end

      define_method(:call) do |context:, **|
        raise NotImplementedError, "AgentTool#call should not be invoked directly — AgentRuntime handles dispatch"
      end
    end
  end
end
