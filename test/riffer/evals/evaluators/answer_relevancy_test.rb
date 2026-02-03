# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Evaluators::AnswerRelevancy do
  describe "class configuration" do
    it "has identifier set to answer_relevancy" do
      expect(Riffer::Evals::Evaluators::AnswerRelevancy.identifier).must_equal "answer_relevancy"
    end

    it "has a description" do
      expect(Riffer::Evals::Evaluators::AnswerRelevancy.description).wont_be_nil
    end

    it "has higher_is_better set to true" do
      expect(Riffer::Evals::Evaluators::AnswerRelevancy.higher_is_better).must_equal true
    end
  end

  describe "registry" do
    it "is registered in the evaluators registry" do
      evaluator_class = Riffer::Evals::Evaluators::Registry.find("answer_relevancy")
      expect(evaluator_class).must_equal Riffer::Evals::Evaluators::AnswerRelevancy
    end
  end

  describe "#evaluate" do
    it "requires judge_model to be configured" do
      # Ensure no judge model is configured
      original_judge_model = Riffer.config.evals.judge_model
      Riffer.config.evals.judge_model = nil

      evaluator = Riffer::Evals::Evaluators::AnswerRelevancy.new

      error = expect {
        evaluator.evaluate(input: "What is Ruby?", output: "Ruby is a language.")
      }.must_raise(Riffer::ArgumentError)

      expect(error.message).must_match(/No judge model configured/)

      Riffer.config.evals.judge_model = original_judge_model
    end

    # Integration tests with VCR would go here for real API calls
    # describe "with VCR" do
    #   it "evaluates relevant response" do
    #     VCR.use_cassette("answer_relevancy_relevant") do
    #       Riffer.config.evals.judge_model = "anthropic/claude-sonnet-4-20250514"
    #       evaluator = Riffer::Evals::Evaluators::AnswerRelevancy.new
    #
    #       result = evaluator.evaluate(
    #         input: "What is the capital of France?",
    #         output: "The capital of France is Paris."
    #       )
    #
    #       expect(result.score).must_be :>=, 0.8
    #     end
    #   end
    # end
  end

  describe "SYSTEM_PROMPT" do
    it "includes scoring criteria" do
      prompt = Riffer::Evals::Evaluators::AnswerRelevancy::SYSTEM_PROMPT
      expect(prompt).must_include "score"
      expect(prompt).must_include "JSON"
    end
  end
end
