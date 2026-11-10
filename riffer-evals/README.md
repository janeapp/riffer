# riffer-evals

LLM-as-judge evals for [Riffer](https://riffer.ai) agents: define evaluators, run them over scenarios, and read per-scenario and aggregate scores.

## Installation

Add the gem alongside riffer:

```ruby
gem "riffer"
gem "riffer-evals"
```

Bundler requires it for you. Without Bundler, require it before anything requires riffer:

```ruby
require "riffer-evals"
```

riffer-evals provides the same `Riffer::Evals` API as riffer's deprecated built-in copy, which riffer skips loading once this gem is installed. Moving over means adding the gem and switching the judge model setting below.

## Configuration

Set the default judge model, a `provider/model` string, used by evaluators that don't set their own:

```ruby
Riffer::Evals.configure do |config|
  config.judge_model = "anthropic/claude-opus-4-5-20251101"
end
```

This replaces riffer's deprecated `Riffer.config.evals.judge_model`.

## Usage

```ruby
class AnswerRelevancyEvaluator < Riffer::Evals::Evaluator
  instructions "Assess how well the response addresses the question. Score between 0.0 and 1.0."
end

result = Riffer::Evals::EvaluatorRunner.run(
  agent: MyAgent,
  scenarios: [{ input: "What is Ruby?", ground_truth: "A programming language" }],
  evaluators: [AnswerRelevancyEvaluator]
)

result.scores # => { AnswerRelevancyEvaluator => 0.85 }
```

See the [Evals guide](https://riffer.ai/guides/evals/) for evaluators, results, and CI integration.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
