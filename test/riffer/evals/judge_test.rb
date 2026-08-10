# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Judge do
  describe "#initialize" do
    it "sets the model" do
      judge = Riffer::Evals::Judge.new(model: "mock/eval-model")

      expect(judge.model).must_equal "mock/eval-model"
    end

    it "raises error for invalid model string" do
      error = expect do
        Riffer::Evals::Judge.new(model: "invalid-format")
      end.must_raise(Riffer::ArgumentError)

      expect(error.message).must_match(/Invalid model string: invalid-format/)
    end
  end

  describe "#evaluate" do
    it "evaluates with instructions, input, and output" do
      judge = Riffer::Evals::Judge.new(model: "mock/eval-model")
      provider = judge.send(:provider_instance)
      provider.stub_response("",
                             tool_calls: [{ name: "evaluation",
                                            arguments: { score: 0.85, reason: "Good response." }, }],)

      result = judge.evaluate(
        instructions: "Assess answer relevancy.",
        input: "What is Ruby?",
        output: "Ruby is a programming language.",
      )

      expect(result).must_equal({ score: 0.85, reason: "Good response.", token_usage: nil })
    end

    it "returns token usage from the provider response" do
      judge = Riffer::Evals::Judge.new(model: "mock/eval-model")
      provider = judge.send(:provider_instance)
      provider.stub_response(
        "",
        tool_calls: [{ name: "evaluation", arguments: { score: 0.85, reason: "Good response." } }],
        token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 42, output_tokens: 7),
      )

      result = judge.evaluate(
        instructions: "Assess answer relevancy.",
        input: "What is Ruby?",
        output: "Ruby is a programming language.",
      )

      expect(result[:token_usage].total_tokens).must_equal 49
    end

    it "evaluates with ground_truth" do
      judge = Riffer::Evals::Judge.new(model: "mock/eval-model")
      provider = judge.send(:provider_instance)
      provider.stub_response("",
                             tool_calls: [{ name: "evaluation",
                                            arguments: { score: 0.9, reason: "Matches ground truth." }, }],)

      result = judge.evaluate(
        instructions: "Compare output to ground truth.",
        input: "What is the capital of France?",
        output: "Paris is the capital.",
        ground_truth: "Paris",
      )

      expect(result).must_equal({ score: 0.9, reason: "Matches ground truth.", token_usage: nil })
    end
  end
end
