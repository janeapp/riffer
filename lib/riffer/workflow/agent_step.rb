# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Workflow::AgentStep defines a workflow step that executes an Agent.
# The step takes the workflow input, formats it as JSON, and passes it to the agent's +generate+ method. The agent's response is expected to be in a structured format that can be returned
# as the step's output.
class Riffer::Workflow::AgentStep < Riffer::Workflow::Step
    class << self
        # Returns the agent class associated with this step, creating a new one if it doesn't exist.
        # The agent class is lazily initialized to allow the step class to be defined without immediately defining the agent.
        # The agent class is where you would define the prompt and any parameters for the agent to use when generating a response.
        #
        #--
        #: () -> Class
        def agent_class
            @agent_class ||= Class.new(Riffer::Agent)
        end

        # Delegates missing class methods to the agent class, allowing you to define the agent's prompt and parameters directly on the step class.
        # If the agent class does not respond to the method, it falls back to the default behavior of method_missing.
        #
        #--
        #: (Symbol, Array[untyped], ?{ () -> void }) -> untyped        
        def method_missing(name, *args, &block)
            if agent_class.respond_to?(name)
                agent_class.public_send(name, *args, &block)
            else
                super
            end
        end

        # Overrides respond_to_missing? to account for methods defined on the agent class.
        #
        #--
        #: (Symbol, bool) -> bool
        def respond_to_missing?(name, include_private = false)
            agent_class.respond_to?(name) || super
        end

        # Overrides the output_schema class method to also define the structured output for the agent class.
        # When the output schema is defined for the step, it also sets that schema on the agent's structured output, ensuring that the agent's response will be validated against the same schema.
        #
        #--
        #: (?Riffer::Params) ?{ () -> void } -> Riffer::Params
        def output_schema(params = nil, &block)
            result = super(params, &block)

            if result
                agent_class.structured_output(params, &block)
            end
            result
        end
    end

    # Executes the agent step by generating a response from the associated agent class.
    # The input to the step is formatted as JSON and passed to the agent's +generate+ method. The agent's response is expected to be in a structured format that can be returned as the step's output.
    #
    #--
    #: (Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
    def execute(input)
        # validate agent setup before executing
        
        
        agent = self.class.agent_class.new
        data = JSON.pretty_generate(input)
        response = agent.generate(data)
        response.structured_output
    end
end
