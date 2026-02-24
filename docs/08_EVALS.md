# Evals

Evals let you measure the quality of agent outputs using LLM-as-judge evaluations.

> **Tip:** See `examples/evaluators/` for ready-to-use reference implementations you can copy into your project.

## Overview

Riffer Evals provides a framework for evaluating agent responses against configurable quality metrics. It uses an LLM-as-judge approach where a separate model evaluates the outputs of your agents.

Key concepts:

- **Evaluators** - Classes that evaluate input/output pairs and return scores
- **Metrics** - Evaluator configurations with pass/fail thresholds
- **Profiles** - Collections of metrics that can be included in agents
- **Results** - Individual evaluation scores and aggregate pass/fail status

## Quick Start

```ruby
# 1. Configure the judge model
Riffer.config.evals.judge_model = "anthropic/claude-opus-4-5-20251101"

# 2. Define an eval profile
module QualityEvals
  include Riffer::Evals::Profile

  ai_evals do
    metric AnswerRelevancyEvaluator, min: 0.85
  end
end

# 3. Include in your agent
class MyAgent < Riffer::Agent
  include QualityEvals
  model "anthropic/claude-haiku-4-5-20251001"
  instructions "You are a helpful assistant."
end

# 4. Run evals
result = MyAgent.run_eval(input: "What is Ruby?")
result.passed?         # => true/false
result.aggregate_score # => 0.91
```

## Configuration

Before using evals, configure the judge model:

```ruby
Riffer.config.evals.judge_model = "anthropic/claude-opus-4-5-20251101"
```

The judge model is the LLM that evaluates agent outputs. You can use any configured provider.

## Eval Profiles

Eval profiles define which evaluators to run and their pass/fail thresholds.

### Defining a Profile

```ruby
module QualityEvals
  include Riffer::Evals::Profile

  ai_evals do
    metric AnswerRelevancyEvaluator, min: 0.85
  end
end
```

### Metric Options

- `min` - Minimum score to pass (for higher_is_better evaluators)
- `max` - Maximum score to pass (for lower_is_better evaluators)
- `weight` - Weight for aggregate scoring (default: 1.0)

```ruby
ai_evals do
  metric AnswerRelevancyEvaluator, min: 0.85, weight: 2.0  # Weighted more heavily
end
```

### Including in Agents

```ruby
class MyAgent < Riffer::Agent
  include QualityEvals
  model "anthropic/claude-haiku-4-5-20251001"
end
```

## Running Evals

Once a profile is included, call `.run_eval` on the agent class:

```ruby
result = MyAgent.run_eval(
  input: "What is the capital of France?",
  ground_truth: "Paris"  # Optional reference answer
)

# You can also pass a messages array as input
result = MyAgent.run_eval(
  input: [
    { role: "user", content: "What is Ruby?" },
    { role: "assistant", content: "Ruby is a programming language." },
    { role: "user", content: "What makes it special?" }
  ]
)
```

### RunResult Object

The eval method returns a `Riffer::Evals::RunResult`:

```ruby
result.passed?          # => true if all metrics pass thresholds
result.aggregate_score  # => Weighted average of normalized scores (0.0-1.0)
result.failures         # => Array of Result objects that failed
result.results          # => Array of all Result objects
result.input            # => The input that was evaluated
result.output           # => The agent's output
result.ground_truth     # => The ground truth (if provided)
result.to_h             # => Hash representation
```

### Result Object

Individual evaluation results:

```ruby
result.results.first.evaluator       # => AnswerRelevancyEvaluator
result.results.first.score           # => 0.92
result.results.first.reason          # => "The response directly addresses..."
result.results.first.higher_is_better # => true
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

Reference your custom evaluator class directly in eval profiles:

```ruby
ai_evals do
  metric MedicalAccuracyEvaluator, min: 0.9
end
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

## Aggregate Scoring

The `aggregate_score` normalizes all scores so higher is always better:

- For `higher_is_better` evaluators: score is used directly
- For `lower_is_better` evaluators: score is inverted (1.0 - score)

Scores are then weighted:

```ruby
# With weights: relevancy=2.0, toxicity=1.0
# relevancy score: 0.9 (higher_is_better)
# toxicity score: 0.1 (lower_is_better)

# Normalized: relevancy=0.9, toxicity=0.9 (1.0 - 0.1)
# Weighted average: (0.9 * 2.0 + 0.9 * 1.0) / (2.0 + 1.0) = 0.9
```

## Example: Full Integration

```ruby
# config/initializers/riffer.rb
Riffer.configure do |config|
  config.anthropic.api_key = ENV["ANTHROPIC_API_KEY"]
  config.evals.judge_model = "anthropic/claude-opus-4-5-20251101"
end

# app/evals/quality_evals.rb
module QualityEvals
  include Riffer::Evals::Profile

  ai_evals do
    metric AnswerRelevancyEvaluator, min: 0.85, weight: 2.0
  end
end

# app/agents/support_agent.rb
class SupportAgent < Riffer::Agent
  include QualityEvals

  model "anthropic/claude-opus-4-5-20251101"
  instructions "You are a helpful customer support agent."
end

# test/agents/support_agent_test.rb
class SupportAgentTest < Minitest::Test
  def test_response_quality
    result = SupportAgent.run_eval(
      input: "How do I reset my password?",
      ground_truth: "Navigate to Settings > Security > Reset Password"
    )

    assert result.passed?, "Expected eval to pass: #{result.failures.map(&:reason)}"
    assert result.aggregate_score >= 0.85
  end
end
```
