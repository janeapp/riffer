# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::StepResult do
    describe ".initialize" do
        it "initializes with the given step and input, and sets default values for output, success, and error" do
            step = Riffer::Workflow::Step.new
            input = { key: "value" }
            step_result = Riffer::Workflow::StepResult.new(step, input)

            expect(step_result.step).must_equal step
            expect(step_result.input).must_equal input
            expect(step_result.output).must_be_nil
            expect(step_result.success).must_equal false
            expect(step_result.error).must_be_nil
        end
    end
end