# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Evaluators::AnswerRelevancy do
  describe "repository" do
    it "is registered in the evaluators repository" do
      evaluator_class = Riffer::Evals::Evaluators::Repository.find(:answer_relevancy)
      expect(evaluator_class).must_equal Riffer::Evals::Evaluators::AnswerRelevancy
    end
  end

  describe "#evaluate" do
    it "requires judge_model to be configured" do
      original_judge_model = Riffer.config.evals.judge_model
      Riffer.config.evals.judge_model = nil

      evaluator = Riffer::Evals::Evaluators::AnswerRelevancy.new

      error = expect {
        evaluator.evaluate(input: "What is Ruby?", output: "Ruby is a language.")
      }.must_raise(Riffer::ArgumentError)

      expect(error.message).must_match(/No judge model configured/)

      Riffer.config.evals.judge_model = original_judge_model
    end
  end

  describe "integration with test provider" do
    it "evaluates and returns a result" do
      original = Riffer.config.evals.judge_model
      Riffer.config.evals.judge_model = "test/test-model"

      evaluator = Riffer::Evals::Evaluators::AnswerRelevancy.new
      provider = evaluator.send(:judge).send(:provider_instance)
      provider.stub_response("", tool_calls: [{name: "evaluation", arguments: {score: 0.85, reason: "Relevant response."}}])

      result = evaluator.evaluate(
        input: "What is the capital of France?",
        output: "The capital of France is Paris."
      )

      expect(result.score).must_equal 0.85

      Riffer.config.evals.judge_model = original
    end
  end
end
