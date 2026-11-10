# frozen_string_literal: true

require "test_helper"

describe Riffer::Evals::Judge do
  describe "#initialize" do
    it "sets the model" do
      judge = Riffer::Evals::Judge.new(model: "mock/eval-model")

      expect(judge.model).must_equal "mock/eval-model"
    end

    it "defaults the identifier" do
      expect(Riffer::Evals::Judge.new(model: "mock/eval-model").identifier).must_equal "riffer/judge"
    end

    it "raises error for invalid model string" do
      judge = Riffer::Evals::Judge.new(model: "invalid-format")

      error = expect do
        judge.evaluate(instructions: "Assess.", input: "Hi", output: "Hello")
      end.must_raise(Riffer::ArgumentError)

      expect(error.message).must_match(/Invalid model string: invalid-format/)
    end
  end

  describe "#evaluate" do
    let(:provider) { register_judge_provider(:judge_test) }
    let(:judge) { Riffer::Evals::Judge.new(model: "judge_test/eval-model", identifier: "accuracy_evaluator") }

    after { Riffer::Providers::Repository.unregister(:judge_test) }

    def evaluate(judge, **options)
      judge.evaluate(instructions: "Assess answer relevancy.", input: "What is Ruby?", output: "A language.", **options)
    end

    it "parses the score and reason" do
      provider.stub_response('{"score": 0.85, "reason": "Good response."}')

      expect(evaluate(judge)).must_equal({ score: 0.85, reason: "Good response.", token_usage: nil })
    end

    it "returns token usage from the provider response" do
      provider.stub_response(
        '{"score": 0.85, "reason": "Good response."}',
        token_usage: Riffer::Providers::TokenUsage.new(input_tokens: 42, output_tokens: 7),
      )

      expect(evaluate(judge)[:token_usage].total_tokens).must_equal 49
    end

    it "tags the call with the judge kind and the evaluator identifier" do
      provider.stub_response('{"score": 0.85, "reason": "Good response."}')
      evaluate(judge)

      expect(provider.calls.last[:tags]).must_equal({ "kind" => "judge", "agent" => "accuracy_evaluator" })
    end

    it "sends the instructions as the system prompt and the input and output as the user prompt" do
      provider.stub_response('{"score": 0.85, "reason": "Good response."}')
      evaluate(judge)
      system, user = provider.calls.last[:messages]

      expect(system[:content]).must_include "Assess answer relevancy."
      expect(user[:content]).must_equal "## Input\n\nWhat is Ruby?\n\n## Output\n\nA language."
    end

    it "includes the ground truth when given" do
      provider.stub_response('{"score": 0.9, "reason": "Matches ground truth."}')
      evaluate(judge, ground_truth: "A programming language.")

      expect(provider.calls.last[:messages].last[:content]).must_include "## Ground Truth\n\nA programming language."
    end

    it "asks for a score and reason as structured output" do
      provider.stub_response('{"score": 0.85, "reason": "Good response."}')
      evaluate(judge)
      schema = provider.calls.last[:structured_output].json_schema

      expect(schema[:required]).must_equal %w[score reason]
    end

    it "raises when the response does not match the schema" do
      provider.stub_response('{"reason": "No score."}')
      error = expect { evaluate(judge) }.must_raise Riffer::Error

      expect(error.message).must_match(/\AInvalid judge response: /)
    end
  end
end
