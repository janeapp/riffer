# frozen_string_literal: true

require "test_helper"

describe "riffer-evals loading" do
  let(:gem_lib_dir) { File.expand_path("../../../lib/", __dir__) }

  it "replaces riffer's own Riffer::Evals" do
    path, = Riffer::Evals::Evaluator.instance_method(:evaluate).source_location

    expect(path).must_be :start_with?, gem_lib_dir
  end

  it "reports no deprecation when evaluators run" do
    evaluator_class = Class.new(Riffer::Evals::Evaluator) do
      def evaluate(input:, output:, ground_truth: nil, messages: [])
        result(score: 1.0)
      end
    end
    agent_class = Class.new(Riffer::Agent) do
      identifier "loading_agent"
      model "mock/mock-model"
    end

    result = Riffer::Evals::EvaluatorRunner.run(
      agent: agent_class,
      scenarios: [{ input: "Hi" }],
      evaluators: [evaluator_class],
    )

    expect(result.scores[evaluator_class]).must_equal 1.0
  end

  it "eager loads" do
    Zeitwerk::Loader.eager_load_all

    expect(Riffer::Evals::VERSION).must_match(/\A\d+\.\d+\.\d+/)
  end
end
