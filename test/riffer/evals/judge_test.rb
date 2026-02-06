# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Judge do
  describe "#initialize" do
    it "sets the model" do
      judge = Riffer::Evals::Judge.new(model: "test/eval-model")
      expect(judge.model).must_equal "test/eval-model"
    end

    it "raises error for invalid model string" do
      error = expect {
        Riffer::Evals::Judge.new(model: "invalid-format")
      }.must_raise(Riffer::ArgumentError)

      expect(error.message).must_match(/Invalid model string: invalid-format/)
    end
  end

  describe "#evaluate" do
    it "evaluates with system_prompt and user_prompt" do
      judge = Riffer::Evals::Judge.new(model: "test/eval-model")
      provider = judge.send(:provider_instance)
      provider.stub_response("", tool_calls: [{name: "evaluation", arguments: {score: 0.85, reason: "Good response."}}])

      result = judge.evaluate(system_prompt: "You are a judge.", user_prompt: "Evaluate this.")

      expect(result).must_equal({score: 0.85, reason: "Good response."})
    end

    it "evaluates with messages array" do
      judge = Riffer::Evals::Judge.new(model: "test/eval-model")
      provider = judge.send(:provider_instance)
      provider.stub_response("", tool_calls: [{name: "evaluation", arguments: {score: 0.9, reason: "Excellent."}}])

      messages = [
        {role: "system", content: "You are a judge."},
        {role: "user", content: "Evaluate this."}
      ]
      result = judge.evaluate(messages: messages)

      expect(result).must_equal({score: 0.9, reason: "Excellent."})
    end

    it "raises error when both messages and system_prompt/user_prompt provided" do
      judge = Riffer::Evals::Judge.new(model: "test/eval-model")

      error = expect {
        judge.evaluate(messages: [], system_prompt: "test")
      }.must_raise(Riffer::ArgumentError)

      expect(error.message).must_equal "cannot provide both messages and system_prompt/user_prompt"
    end

    it "raises error when user_prompt is missing" do
      judge = Riffer::Evals::Judge.new(model: "test/eval-model")

      error = expect {
        judge.evaluate(system_prompt: "test")
      }.must_raise(Riffer::ArgumentError)

      expect(error.message).must_equal "user_prompt is required when messages is not provided"
    end
  end
end
