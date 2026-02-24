# Evals

Evals let you measure the quality of agent outputs using LLM-as-judge evaluations.

> **Tip:** See `examples/evaluators/` for ready-to-use reference implementations you can copy into your project.

## Overview

Riffer Evals provides a framework for evaluating agent responses against configurable quality evaluators. It uses an LLM-as-judge approach where a separate model evaluates the outputs of your agents.

Key concepts:

- **Evaluators** - Classes that evaluate input/output pairs and return scores
- **Scenarios** - Input/ground-truth pairs that define what to test
- **EvaluatorRunner** - Orchestrates running evaluators across scenarios
- **Results** - Per-scenario and aggregate evaluation scores

## Quick Start

```ruby
# 1. Configure the judge model
Riffer.config.evals.judge_model = "anthropic/claude-opus-4-5-20251101"

# 2. Define your agent
class MyAgent < Riffer::Agent
  model "anthropic/claude-haiku-4-5-20251001"
  instructions "You are a helpful assistant."
end

# 3. Run evals
result = Riffer::Evals::EvaluatorRunner.run(
  agent: MyAgent,
  scenarios: [
    { input: "What is Ruby?", ground_truth: "A programming language" },
    { input: "What is Python?" }
  ],
  evaluators: [AnswerRelevancyEvaluator]
)

result.scores   # => { AnswerRelevancyEvaluator => 0.85 }
```

## Configuration

Before using evals, configure the judge model:

```ruby
Riffer.config.evals.judge_model = "anthropic/claude-opus-4-5-20251101"
```

The judge model is the LLM that evaluates agent outputs. You can use any configured provider.

## Example Evaluators

Ready-to-use evaluator implementations are available in `examples/evaluators/`. Copy them into your project and customize as needed.

### AnswerRelevancy

Evaluates how well a response addresses the input question.

- **higher_is_better**: true
- **Score range**: 0.0 to 1.0
- **1.0**: Perfectly relevant, directly addresses the question
- **0.7-0.9**: Mostly relevant with minor tangents
- **0.4-0.6**: Partially relevant, some off-topic content
- **0.1-0.3**: Mostly irrelevant
- **0.0**: Completely irrelevant

## Running Evals

Use `EvaluatorRunner.run` with an agent class, scenarios, and evaluator classes:

```ruby
result = Riffer::Evals::EvaluatorRunner.run(
  agent: MyAgent,
  scenarios: [
    { input: "What is the capital of France?", ground_truth: "Paris" },
    { input: "Explain Ruby blocks." }
  ],
  evaluators: [AnswerRelevancyEvaluator]
)
```

### Tool Context

Pass `tool_context:` to provide context that agents use for dynamic model selection, tool resolution, or tool execution:

```ruby
result = Riffer::Evals::EvaluatorRunner.run(
  agent: MyAgent,
  scenarios: [
    { input: "What is Ruby?" },
    { input: "Premium question", tool_context: { premium: true } }
  ],
  evaluators: [AnswerRelevancyEvaluator],
  tool_context: { premium: false }
)
```

Per-scenario `tool_context` overrides the top-level value. Scenarios without their own `tool_context` inherit the top-level value.

### RunResult

The runner returns a `Riffer::Evals::RunResult`:

```ruby
result.scores             # => { EvaluatorClass => avg_score } across all scenarios
result.scenario_results   # => Array of ScenarioResult objects
result.to_h               # => Hash representation
```

### ScenarioResult

Each scenario produces a `Riffer::Evals::ScenarioResult`:

```ruby
scenario = result.scenario_results.first
scenario.input        # => "What is the capital of France?"
scenario.output       # => "The capital of France is Paris."
scenario.ground_truth # => "Paris"
scenario.scores       # => { EvaluatorClass => score } for this scenario
scenario.results      # => Array of Result objects
scenario.to_h         # => Hash representation
```

### Result

Individual evaluation results:

```ruby
r = scenario.results.first
r.evaluator        # => AnswerRelevancyEvaluator
r.score            # => 0.92
r.reason           # => "The response directly addresses..."
r.higher_is_better # => true
```

## Defining Custom Evaluators

Create evaluators by subclassing `Riffer::Evals::Evaluator`. The simplest approach uses the `instructions` DSL — the base class handles calling the judge automatically:

```ruby
class MedicalAccuracyEvaluator < Riffer::Evals::Evaluator
  higher_is_better true
  judge_model "anthropic/claude-opus-4-5-20251101"  # Optional override

  instructions <<~TEXT
    Assess the medical accuracy of the response.

    Score between 0.0 and 1.0 where:
      - 1.0 = Medically accurate and complete
      - 0.7-0.9 = Mostly accurate with minor omissions
      - 0.4-0.6 = Partially accurate
      - 0.1-0.3 = Mostly inaccurate
      - 0.0 = Completely inaccurate

    When ground truth is provided, compare the response against it.
  TEXT
end
```

The judge receives `input`, `output`, and optionally `ground_truth` alongside your instructions. No manual prompt composition needed.

### Using Custom Evaluators

Pass your custom evaluator class to the runner:

```ruby
result = Riffer::Evals::EvaluatorRunner.run(
  agent: MyAgent,
  scenarios: [{ input: "What are symptoms of flu?" }],
  evaluators: [MedicalAccuracyEvaluator]
)
```

### Evaluator DSL

Class methods:

- `instructions(value)` - Evaluation criteria and scoring rubric (enables default `evaluate`)
- `higher_is_better(value)` - Whether higher scores are better (default: true)
- `judge_model(value)` - Override the global judge model

Instance methods:

- `evaluate(input:, output:, ground_truth:)` - Override for custom logic; default calls judge with `instructions`
- `judge` - Returns a Judge instance for LLM-as-judge calls
- `result(score:, reason:, metadata:)` - Helper to build Result objects

### Advanced: Custom Evaluate Override

For evaluators that need full control over the evaluation logic, override `evaluate` directly:

```ruby
class CustomEvaluator < Riffer::Evals::Evaluator
  higher_is_better true
  judge_model "anthropic/claude-opus-4-5-20251101"

  def evaluate(input:, output:, ground_truth: nil)
    evaluation = judge.evaluate(
      instructions: "Custom evaluation criteria...",
      input: input,
      output: output,
      ground_truth: ground_truth
    )

    result(score: evaluation[:score], reason: evaluation[:reason])
  end
end
```

### Rule-Based Evaluators

Evaluators don't have to use LLM-as-judge:

```ruby
class LengthEvaluator < Riffer::Evals::Evaluator
  higher_is_better true

  def evaluate(input:, output:, ground_truth: nil)
    min_length = 50
    max_length = 500

    length = output.length

    if length < min_length
      score = length.to_f / min_length
      reason = "Response too short (#{length} < #{min_length})"
    elsif length > max_length
      score = max_length.to_f / length
      reason = "Response too long (#{length} > #{max_length})"
    else
      score = 1.0
      reason = "Response length is appropriate"
    end

    result(score: score, reason: reason)
  end
end
```

## Example: CI Integration

```ruby
# config/initializers/riffer.rb
Riffer.configure do |config|
  config.anthropic.api_key = ENV["ANTHROPIC_API_KEY"]
  config.evals.judge_model = "anthropic/claude-opus-4-5-20251101"
end

# app/agents/support_agent.rb
class SupportAgent < Riffer::Agent
  model "anthropic/claude-opus-4-5-20251101"
  instructions "You are a helpful customer support agent."
end

# test/evals/support_agent_eval_test.rb
class SupportAgentEvalTest < Minitest::Test
  def test_response_quality
    result = Riffer::Evals::EvaluatorRunner.run(
      agent: SupportAgent,
      scenarios: [
        { input: "How do I reset my password?", ground_truth: "Navigate to Settings > Security > Reset Password" },
        { input: "What are your business hours?" }
      ],
      evaluators: [AnswerRelevancyEvaluator]
    )

    result.scores.each do |evaluator, score|
      assert score >= 0.85, "#{evaluator.name} scored #{score}, expected >= 0.85"
    end
  end
end
```
