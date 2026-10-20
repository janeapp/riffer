# Structured output benchmark: Riffer `:prompted` vs Bedrock `:native`

Compares Riffer's prompted structured-output strategy with Bedrock's native constrained decoding on Claude models, using riffer's own Bedrock provider and `Riffer::Agent::StructuredOutput`. It measures schema acceptance, validity, field accuracy and hallucination against deterministic ground truth, tool misuse (calling tools when everything is in the prompt, skipping tools when the data only exists behind them), and latency (TTFT and total run time).

## Files

| File | Purpose |
| --- | --- |
| `bench.rb` | Runs every model × scenario × strategy × rep and appends one JSON line per run |
| `probe_limits.rb` | Sends riffer-generated strict schemas to native and records which Bedrock accepts |
| `probe_non_strict.rb` | Checks whether non-strict schemas (optional instead of nullable) avoid the limits |
| `selftest.rb` | Checks the graders: perfect answers score 100%, planted hallucinations are caught |
| `report.rb` | Renders a self-contained HTML report from the JSONL and limits JSON |
| `lib/` | Fake clinic backend and tools, fixture documents, scenarios, graders and the streaming harness |
| `results/` | Raw results from 2026-10-20 (scenario runs, forced-choice runs, 100-run reliability cells, schema limits) and the rendered report |

## Running

```sh
export AWS_PROFILE=...   # any profile that can call bedrock-runtime Converse in us-west-2
bundle exec ruby examples/structured_output_benchmark/selftest.rb
bundle exec ruby examples/structured_output_benchmark/bench.rb --reps 5 --concurrency 8 --out results/run.jsonl
bundle exec ruby examples/structured_output_benchmark/probe_limits.rb \
  --models us.anthropic.claude-haiku-5-5,us.anthropic.claude-sonnet-5-5,us.anthropic.claude-opus-5-5 --out results/limits.json
bundle exec ruby examples/structured_output_benchmark/bench.rb --scenarios intake_lite,previsit_tools,chat --reps 100 --concurrency 12 \
  --out results/reliability.jsonl
ruby examples/structured_output_benchmark/report.rb --results results/run.jsonl,results/forced-choice.jsonl \
  --reliability results/reliability.jsonl --limits results/limits.json --out report.html
```

`bench.rb` accepts `--models`, `--strategies`, `--scenarios`, `--reps`, `--concurrency`, `--region`, `--out` and `--resume`.

`Riffer::Agent` refuses to stream when structured output is configured, so the harness runs the same tool loop over the provider's `stream_text` to observe time to first token. Request building, prompted-schema injection and `parse_and_validate` are riffer's own.
