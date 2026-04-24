# frozen_string_literal: true

require "test_helper"

Riffer.configure do |config|
    config.openai.api_key = ENV['OPENAPI_KEY']
end

describe Riffer::Workflow::Base do
    it "simple execution test" do
        class AddOneStep < Riffer::Workflow::Step
            input_schema do
                required :start_num, Integer 
            end

            output_schema do
                required :result, Integer
            end

            def execute(input)
                { result: input[:start_num] + 1 }
            end
        end

        class MultiplyByTwoStep < Riffer::Workflow::Step
            input_schema do
                required :result, Integer 
            end

            output_schema do
                required :final_result, Integer
            end

            def execute(input)
                { final_result: input[:result] * 2 }
            end
        end

        class MyWorkflow < Riffer::Workflow::Base
            input_schema do
                required :start_num, Integer 
            end

            output_schema do
                required :final_result, Integer
            end

            step AddOneStep
            step MultiplyByTwoStep
        end

        result = MyWorkflow.execute(start_num: 5)
        expect(result.result[:final_result]).must_equal 12
    end

    it "AgentStep test" do
        class PlusTenTool < Riffer::Tool
            description "Adds 10 to the passed in number"

            params do
                required :input, Integer, description: "The number to add 10 to"
            end

            def call(context:, input:)
                puts "invoking tool"
                json({ result: input + 10})
            end
        end

        class PlusTenAgentStep < Riffer::Workflow::AgentStep
            input_schema do
                required :start_num, Integer 
            end

            output_schema do
                required :final_result, Integer
            end

            model 'openai/gpt-5.4-nano'
            instructions "Call the plus_ten tool with the start_num input and return the output"
            uses_tools [PlusTenTool]
        end

        class AgentWorkflow < Riffer::Workflow::Base
            input_schema do
                required :start_num, Integer 
            end

            output_schema do
                required :final_result, Integer
            end

            step PlusTenAgentStep
        end

        result = AgentWorkflow.execute(start_num: 5)
        expect(result.result[:final_result]).must_equal 15
    end
end