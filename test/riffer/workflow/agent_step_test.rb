# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::AgentStep do
    it "agent class isn't defined, creates a new agent" do
        class MyAgentStep < Riffer::Workflow::AgentStep
        end

        expect(MyAgentStep.agent_class).must_be :<, Riffer::Agent
    end

    it "agent class isn't recreated once defined" do
        class MyAgentStep2 < Riffer::Workflow::AgentStep
        end

        agent_class = MyAgentStep2.agent_class
        expect(MyAgentStep2.agent_class).must_equal agent_class
    end

    it "delegates missing methods to the agent class" do
        class MyAgentStep3 < Riffer::Workflow::AgentStep
            model "openai/gpt-5-mini"
        end

        expect(MyAgentStep3.agent_class.model).must_equal "openai/gpt-5-mini"
    end

    it "output_schema also sets structured output for the agent class" do
        class MyAgentStep4 < Riffer::Workflow::AgentStep
            output_schema do
                required :result, Integer
            end
        end

        expect(MyAgentStep4.agent_class.structured_output).wont_be_nil
        expect(MyAgentStep4.agent_class.structured_output.is_equal?(MyAgentStep4.output_schema)).must_equal true
    end

    it "execute raises error if structured output is not defined" do
        class MyAgentStep5 < Riffer::Workflow::AgentStep
            model "openai/gpt-5-mini"
            instructions "Do something"
        end

        step = MyAgentStep5.new
        expect { step.execute({}) }.must_raise Riffer::Workflow::ConfigurationError
    end

    it "execute raises error if model is not defined" do
        class MyAgentStep6 < Riffer::Workflow::AgentStep
            output_schema do
                required :result, Integer
            end
            instructions "Do something"
        end

        step = MyAgentStep6.new
        expect { step.execute({}) }.must_raise Riffer::Workflow::ConfigurationError
    end

    it "execute raises error if instructions are not defined" do
        class MyAgentStep7 < Riffer::Workflow::AgentStep
            output_schema do
                required :result, Integer
            end
            model "openai/gpt-5-mini"
        end

        step = MyAgentStep7.new
        expect { step.execute({}) }.must_raise Riffer::Workflow::ConfigurationError
    end

    it "execute generates a response from the agent and returns the structured output" do        
        class MyAgentStep8 < Riffer::Workflow::AgentStep
            output_schema do
                required :result, Integer
            end
            model "mock/riffer-1"
            instructions "Return { result: 42 }"
            provider_options responses: [ { content: '{"result": 42}' } ]
        end

        step = MyAgentStep8.new
        response = step.execute({})
        expect(response).must_equal({ result: 42 })
    end
end