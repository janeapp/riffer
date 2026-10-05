# Evals

Evals let you measure the quality of agent outputs using LLM-as-judge evaluations.

## When to Use Evals

Use evals when you need to measure agent quality objectively — after changing instructions, switching models, or before deploying to production. Evals catch regressions that manual testing misses because LLM outputs are non-deterministic.

> **Tip:** See [`examples/evaluators/`](https://github.com/janeapp/riffer/tree/main/examples/evaluators) for ready-to-use reference implementations you can copy into your project.

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

Ready-to-use evaluator implementations are available in [`examples/evaluators/`](https://github.com/janeapp/riffer/tree/main/examples/evaluators). Copy them into your project and customize as needed.

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

### Context

Pass `context:` to provide context that agents use for dynamic model selection, tool resolution, or tool execution:

```ruby
result = Riffer::Evals::EvaluatorRunner.run(
  agent: MyAgent,
  scenarios: [
    { input: "What is Ruby?" },
    { input: "Premium question", context: { premium: true } }
  ],
  evaluators: [AnswerRelevancyEvaluator],
  context: { premium: false }
)
```

Per-scenario `context` overrides the top-level value. Scenarios without their own `context` inherit the top-level value.

### Structured Ground Truth

`ground_truth` can be a String or a Hash of expected fields, which suits agents that use [`structured_output`](AGENTS.md#structured_output):

```ruby
result = Riffer::Evals::EvaluatorRunner.run(
  agent: SentimentAgent,
  scenarios: [
    { input: "I love it", ground_truth: { sentiment: "positive" } }
  ],
  evaluators: [SentimentMatchEvaluator]
)
```

The runner passes the Hash to evaluators unchanged. When an LLM-as-judge evaluator forwards it to the judge, the judge renders it as pretty-printed JSON.

### Failing Scenarios

If `agent.generate` raises for a scenario (for example, a provider rejects the request), the runner records the exception on that scenario's result and moves on to the next scenario instead of aborting the run. For an errored scenario:

- `error` holds the exception, and `output`, `outcome`, `structured_output` and `token_usage` are `nil`
- no evaluators run, so `results` and `scores` are empty
- `latency` still records how long the failed call took

Because errored scenarios have no scores, they don't count toward `RunResult#scores` — a run where every scenario errored has empty scores. Check `result.errored_scenario_results` to catch failures (see the [CI example](#example-ci-integration)). Exceptions raised by evaluators themselves are not caught.

### Latency

Each scenario result records `latency`: the seconds spent in `agent.generate`, measured with a monotonic clock. Evaluator time is excluded. Pass `clock:` (a callable returning seconds as a Float) to substitute the clock, e.g. in tests.

### RunResult

The runner returns a `Riffer::Evals::RunResult`:

```ruby
result.scores                   # => { EvaluatorClass => avg_score } across scenarios that did not error
result.scenario_results         # => Array of ScenarioResult objects
result.errored_scenario_results # => ScenarioResults whose agent call raised
result.token_usage              # => TokenUsage the agent under test spent, summed across scenarios (nil if none reported)
result.evaluator_token_usage    # => TokenUsage the judges spent, summed across scenarios (nil if no judge ran)
result.to_h                     # => Hash representation
```

### ScenarioResult

Each scenario produces a `Riffer::Evals::ScenarioResult`:

```ruby
scenario = result.scenario_results.first
scenario.input                  # => "What is the capital of France?"
scenario.output                 # => "The capital of France is Paris." (nil if the agent raised)
scenario.ground_truth           # => "Paris" (String or Hash)
scenario.outcome                # => Riffer::Agent::Outcome describing how the run ended (nil if the agent raised)
scenario.structured_output      # => validated structured output Hash (nil when absent or invalid)
scenario.latency                # => seconds spent in agent.generate
scenario.error                  # => exception raised by agent.generate (nil on success)
scenario.scores                 # => { EvaluatorClass => score } for this scenario
scenario.results                # => Array of Result objects
scenario.messages               # => Array of Message objects (system, user, assistant, tool)
scenario.token_usage            # => TokenUsage the agent under test spent on this scenario (nil if not reported)
scenario.evaluator_token_usage  # => TokenUsage the judges spent on this scenario (nil if no judge ran)
scenario.to_h                   # => Hash representation
```

### Result

Individual evaluation results:

```ruby
r = scenario.results.first
r.evaluator        # => AnswerRelevancyEvaluator
r.score            # => 0.92
r.reason           # => "The response directly addresses..."
r.higher_is_better # => true
r.token_usage      # => TokenUsage for the judge call (nil for rule-based evaluators)
```

`token_usage` is a `Riffer::Providers::TokenUsage`, the same type the agent exposes on `Agent::Response`, so eval usage accumulates with the `+` operator just like agent usage. On a `Result` it's populated for LLM-as-judge evaluators and `nil` for rule-based ones that never call an LLM.

`ScenarioResult` and `RunResult` keep the two sources separate rather than exposing a single total: `token_usage` is what the agent under test spent generating the output, and `evaluator_token_usage` is what the judges spent scoring it. Add them yourself if you want a combined figure.

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

### Evaluator Inputs

The runner calls `evaluate` with these keyword arguments:

- `input` - The scenario input
- `output` - The response `content` string
- `ground_truth` - The scenario's ground truth (String, Hash, or `nil`)
- `messages` - The full message history of the run
- `outcome` - The run's `Riffer::Agent::Outcome`, e.g. `outcome.reason` is `:completed`, `:invalid_structured_output`, `:length` or `:max_steps`
- `structured_output` - The validated structured output Hash riffer accepted (`nil` when the agent has no schema or validation failed)

The runner only passes the keywords your `evaluate` declares (or all of them if it takes `**kwargs`), so evaluators that omit `outcome:` or `structured_output:` keep working.

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
- `identifier(value)` - Override the identifier sent with judge calls (default: the snake_cased class name, or `riffer/judge` for an anonymous class)

Instance methods:

- `evaluate(input:, output:, ground_truth:, messages:, outcome:, structured_output:)` - Override for custom logic; default calls judge with `instructions`. Declare only the keywords you use
- `judge` - Returns a Judge instance for LLM-as-judge calls. Its calls carry the [default tags](AGENTS.md#default-tags) `kind: "judge"` and `agent: <identifier>`
- `result(score:, reason:, metadata:, token_usage:)` - Helper to build Result objects

### Advanced: Custom Evaluate Override

For evaluators that need full control over the evaluation logic, override `evaluate` directly:

```ruby
class CustomEvaluator < Riffer::Evals::Evaluator
  higher_is_better true
  judge_model "anthropic/claude-opus-4-5-20251101"

  def evaluate(input:, output:, ground_truth: nil, messages: [])
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

  def evaluate(input:, output:, ground_truth: nil, messages: [])
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

### Structured Output Evaluators

Combine `outcome`, `structured_output` and a Hash `ground_truth` to check structured responses without re-parsing `content`:

```ruby
class SentimentMatchEvaluator < Riffer::Evals::Evaluator
  def evaluate(input:, output:, ground_truth: nil, outcome: nil, structured_output: nil)
    unless outcome&.success?
      return result(score: 0.0, reason: "Run ended with #{outcome&.reason}: #{outcome&.detail}")
    end

    matched = ground_truth.all? { |field, expected| structured_output[field] == expected }
    result(score: matched ? 1.0 : 0.0, reason: matched ? "All fields match" : "Fields differ")
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

    assert_empty result.errored_scenario_results.map { |s| s.error.message }

    result.scores.each do |evaluator, score|
      assert score >= 0.85, "#{evaluator.name} scored #{score}, expected >= 0.85"
    end
  end
end
```
