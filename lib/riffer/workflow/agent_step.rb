module Riffer
    module Workflow
        class AgentStep < Step
            class << self
                def agent_class
                    @agent_class ||= Class.new(Riffer::Agent)
                end

                def method_missing(name, *args, &block)
                    if agent_class.respond_to?(name)
                        agent_class.public_send(name, *args, &block)
                    else
                        super
                    end
                end

                def respond_to_missing?(name, include_private = false)
                    agent_class.respond_to?(name) || super
                end

                def output_schema(params = nil, &block)
                    result = super(params, &block)

                    if result
                        agent_class.structured_output(params, &block)
                    end
                    result
                end
            end

            def execute(input)
                agent = self.class.agent_class.new
                data = JSON.pretty_generate(input)
                response = agent.generate(data)
                response.structured_output
            end
        end
    end
end