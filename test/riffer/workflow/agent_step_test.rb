# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::AgentStep do
    describe ".agent_class" do
        it "creates a new agent when not defined" do
            class MyAgentStep < Riffer::Workflow::AgentStep
            end

            expect(MyAgentStep.agent_class).must_be :<, Riffer::Agent
        end

        it "doesn't create a new agent once defined" do
            class MyAgentStep1 < Riffer::Workflow::AgentStep
            end

            agent_class = MyAgentStep1.agent_class
            expect(MyAgentStep1.agent_class).must_equal agent_class
        end
    end

    describe ".method_missing" do
        it "delegates missing methods to the agent class" do
            class MyAgentStep2 < Riffer::Workflow::AgentStep
                model "openai/gpt-5-mini"
            end

            expect(MyAgentStep2.agent_class.model).must_equal "openai/gpt-5-mini"
        end
    end

    describe ".output_schema" do
        it "also sets structured output for the agent class" do
            class MyAgentStep3 < Riffer::Workflow::AgentStep
                output_schema do
                    required :result, Integer
                end
            end

            expect(MyAgentStep3.agent_class.structured_output).wont_be_nil
            expect(MyAgentStep3.agent_class.structured_output.is_equal?(MyAgentStep3.output_schema)).must_equal true
        end
    end

    describe "#execute" do
        it "raises an error if input schema is not defined" do
            class MyAgentStep4 < Riffer::Workflow::AgentStep
                output_schema do
                    required :result, Integer
                end
                model "openai/gpt-5-mini"
                instructions "Do something"
            end
            step = MyAgentStep4.new
            expect { step.execute({}) }.must_raise Riffer::Workflow::ConfigurationError
        end

        it "raises an error if structured output is not defined" do
            class MyAgentStep5 < Riffer::Workflow::AgentStep
                input_schema do
                    required :input, String
                end
                model "openai/gpt-5-mini"
                instructions "Do something"
            end

            step = MyAgentStep5.new
            expect { step.execute({}) }.must_raise Riffer::Workflow::ConfigurationError
        end

        it "raises an error if model is not defined" do
            class MyAgentStep6 < Riffer::Workflow::AgentStep
                input_schema do
                    required :input, String
                end
                output_schema do
                    required :result, Integer
                end
                instructions "Do something"
            end

            step = MyAgentStep6.new
            expect { step.execute({}) }.must_raise Riffer::Workflow::ConfigurationError
        end

        it "raises an error if instructions are not defined" do
            class MyAgentStep7 < Riffer::Workflow::AgentStep
                input_schema do
                    required :input, String
                end
                output_schema do
                    required :result, Integer
                end
                model "openai/gpt-5-mini"
            end

            step = MyAgentStep7.new
            expect { step.execute({}) }.must_raise Riffer::Workflow::ConfigurationError
        end

        it "calls generate with the input hash and returns structured output" do
            class MyAgentStep8 < Riffer::Workflow::AgentStep
                input_schema do
                    required :input, String
                end
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
end