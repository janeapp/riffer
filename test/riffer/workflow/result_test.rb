# # frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::Result do
    describe ".initialize" do
        it "initializes with an empty steps array" do
            result = Riffer::Workflow::Result.new
            expect(result.steps).must_be_empty
        end
    end

    describe "#add_step_result" do
        it "adds step results to the end of the array" do
            result = Riffer::Workflow::Result.new
            step_result = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            result.add_step_result(step_result)

            expect(result.steps).must_include step_result
        end
    end

    describe "#succeeded?" do
        it "returns true if all steps succeeded" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = true
            step_result_2.output = "output2"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)
            expect(result.succeeded?).must_equal true
        end

        it "returns false if any step failed" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = false
            step_result_2.output = nil
            step_result_2.error = "error"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)

            expect(result.succeeded?).must_equal false
        end
    end

    describe "#failed?" do
        it "returns true if any step failed" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = false
            step_result_2.output = nil
            step_result_2.error = "error"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)

            expect(result.failed?).must_equal true
        end

        it "returns false if all steps succeeded" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = true
            step_result_2.output = "output2"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)

            expect(result.failed?).must_equal false
        end
    end

    describe "#result" do
        it "returns the output of the last step if succeeded" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = true
            step_result_2.output = "output2"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)
            expect(result.result).must_equal "output2"
        end

        it "result returns nil if failed" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = false
            step_result_2.output = nil
            step_result_2.error = "error"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)

            expect(result.result).must_be_nil
        end
    end

    describe "#error" do
        it "returns the error message of the first failed step if failed" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = false
            step_result_2.output = nil
            step_result_2.error = "error"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)

            expect(result.error).must_equal "error"
        end

        it "error returns nil if succeeded" do
            result = Riffer::Workflow::Result.new
            step_result_1 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_1.success = true
            step_result_1.output = "output1"
            step_result_2 = Riffer::Workflow::StepResult.new(Riffer::Workflow::Step.new, {})
            step_result_2.success = true
            step_result_2.output = "output2"
            result.add_step_result(step_result_1)
            result.add_step_result(step_result_2)

            expect(result.error).must_be_nil
        end
    end
end