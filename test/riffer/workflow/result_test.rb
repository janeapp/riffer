# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::Result do
  describe "success" do
    let(:result) do
      Riffer::Workflow::Result.new(
        status: :success,
        input: {message: "hello"},
        output: {reply: "Done"},
        steps: {
          "step_a" => Riffer::Workflow::StepResult.new(status: :success, payload: {message: "hello"}, output: {reply: "Done"})
        }
      )
    end

    it "is success" do
      expect(result.success?).must_equal true
    end

    it "is not failed" do
      expect(result.failed?).must_equal false
    end

    it "carries the input" do
      expect(result.input).must_equal({message: "hello"})
    end

    it "carries the output" do
      expect(result.output).must_equal({reply: "Done"})
    end

    it "has no error" do
      expect(result.error).must_be_nil
    end

    it "has no failed_step" do
      expect(result.failed_step).must_be_nil
    end

    it "includes step results" do
      expect(result.steps["step_a"].success?).must_equal true
    end
  end

  describe "failed" do
    let(:error) { RuntimeError.new("boom") }
    let(:result) do
      Riffer::Workflow::Result.new(
        status: :failed,
        input: {message: "hello"},
        error: error,
        failed_step: "step_b",
        steps: {
          "step_a" => Riffer::Workflow::StepResult.new(status: :success, payload: {message: "hello"}, output: {x: 1}),
          "step_b" => Riffer::Workflow::StepResult.new(status: :failed, payload: {x: 1}, error: error)
        }
      )
    end

    it "is failed" do
      expect(result.failed?).must_equal true
    end

    it "carries the input" do
      expect(result.input).must_equal({message: "hello"})
    end

    it "carries the error" do
      expect(result.error).must_equal error
    end

    it "identifies the failed step" do
      expect(result.failed_step).must_equal "step_b"
    end

    it "has nil output" do
      expect(result.output).must_be_nil
    end
  end

  describe "#to_h" do
    it "serializes a successful result" do
      result = Riffer::Workflow::Result.new(
        status: :success,
        input: {text: "hi"},
        output: {text: "HI"},
        steps: {
          "upcase" => Riffer::Workflow::StepResult.new(status: :success, payload: {text: "hi"}, output: {text: "HI"})
        }
      )

      expect(result.to_h).must_equal({
        status: :success,
        input: {text: "hi"},
        output: {text: "HI"},
        steps: {
          "upcase" => {status: :success, payload: {text: "hi"}, output: {text: "HI"}}
        }
      })
    end

    it "serializes a pending step result" do
      step_result = Riffer::Workflow::StepResult.new(status: :pending)
      expect(step_result.to_h).must_equal({status: :pending})
    end

    it "serializes a failed result" do
      result = Riffer::Workflow::Result.new(
        status: :failed,
        input: {text: "hi"},
        error: RuntimeError.new("boom"),
        failed_step: "bad_step",
        steps: {
          "bad_step" => Riffer::Workflow::StepResult.new(status: :failed, payload: {text: "hi"}, error: RuntimeError.new("boom"))
        }
      )

      expect(result.to_h).must_equal({
        status: :failed,
        input: {text: "hi"},
        error: "boom",
        failed_step: "bad_step",
        steps: {
          "bad_step" => {status: :failed, payload: {text: "hi"}, error: "boom"}
        }
      })
    end
  end
end
