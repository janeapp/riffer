require 'riffer'

class Step1 < Riffer::Workflow::Step
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

class Step2 < Riffer::Workflow::Step
    input_schema do
        required :result, Integer 
    end

    output_schema do
        required :result, Integer
    end

    def execute(input)
        { final_result: input[:result] * 2 }
    end
end

Riffer.configure do |config|
    config.openai.api_key = ENV['OPENAPI_KEY']
end

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

class Step3 < Riffer::Workflow::AgentStep
    input_schema do
        required :result, Integer 
    end

    output_schema do
        required :final_result, Integer
    end

    model 'openai/gpt-5-mini'
    instructions "Call the plus_ten tool with the input and return the output"
    uses_tools [PlusTenTool]
end

class MyWorkflow < Riffer::Workflow::Base
    input_schema do
        required :start_num, Integer 
    end

    output_schema do
        required :final_result, Integer
    end

    step Step1
    step Step2
    step Step3
end

result = MyWorkflow.execute(start_num: 5)
puts result.result[:final_result] # should output 12

result.steps.each do |step_result|
    puts "Step: #{step_result.step}, Input: #{step_result.input}, Output: #{step_result.output}, Success: #{step_result.success}, Error: #{step_result.error}"
end