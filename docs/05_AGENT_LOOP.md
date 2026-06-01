# Agent Loop

## Tool Execution Flow

When an agent receives a response with tool calls:

1. Agent detects `tool_calls` in the assistant message
2. The configured tool runtime executes the tool calls (sequentially by default, or concurrently with `Riffer::Tools::Runtime::Threaded`):
   - Finds the matching tool class
   - Validates arguments against the tool's parameter schema
   - Calls the tool's `call` method with `context` and arguments
   - Creates a Tool message with the result
3. Sends the updated message history back to the LLM
4. Repeats until no more tool calls

## Error Handling

Tool execution errors are captured and sent back to the LLM:

- `unknown_tool` - Tool not found in registered tools
- `validation_error` - Arguments failed validation
- `execution_error` - Tool raised an exception

The LLM can use this information to retry or respond appropriately.

## Ways the Agent Loop Can Stop

The agent loop normally runs until the LLM produces a response with no tool calls. There are four mechanisms that can stop it early, each designed for a different use case:

### Guardrail Tripwire (declarative, internal)

Guardrails are registered at class definition time and run automatically on every request. When a guardrail calls `block`, it sets a **tripwire** that stops the loop immediately. The LLM is never called (for `:before` guardrails) or its response is discarded (for `:after` guardrails).

- **When to use:** Policy enforcement that should always apply — content filtering, input validation, length limits.
- **Response:** `response.blocked?` returns `true`, `response.tripwire` contains the reason and metadata.
- **Streaming:** Yields a `GuardrailTripwire` event.
- **Resumable:** No. A tripwire is a hard stop. The caller must change the input and start a new `generate`/`stream` call.

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  guardrail :before, with: ContentPolicy
end

response = MyAgent.generate('blocked input')
response.blocked?          # => true
response.tripwire.reason   # => "Content policy violation"
```

### Callback Interrupt (imperative, external)

Callbacks registered with `on_message` can call `agent.interrupt!` (or `throw :riffer_interrupt`) to pause the loop at any point — after receiving an assistant message, after a tool result, etc. The caller controls exactly when and why to interrupt.

- **When to use:** Flow control that depends on runtime decisions — human-in-the-loop approval, budget tracking, conditional pausing.
- **Response:** `response.interrupted?` returns `true`, `response.interrupt_reason` contains the optional reason.
- **Streaming:** Yields an `Interrupt` event with a `reason` attribute.
- **Resumable:** Yes. Call `generate('Continue')` or `stream('Continue')` on the same agent instance to resume. For cross-process resume, pass persisted messages as an array to a new agent. Pending tool calls are automatically executed before the LLM loop resumes.

```ruby
agent = MyAgent.new
agent.session.on_message do |msg|
  agent.interrupt!("approval needed") if requires_approval?(msg)
end

response = agent.generate('Do something risky')
response.interrupted?      # => true
response.interrupt_reason  # => "approval needed"
response = agent.generate('Approved, continue')  # continues where it left off
```

### Max Steps Limit

The `max_steps` class method caps the number of LLM call steps in the tool-use loop. When the step count reaches the limit, the loop interrupts automatically with reason `:max_steps`.

- **When to use:** Safety net to prevent runaway tool-use loops — useful when agents have access to many tools or operate autonomously.
- **Response:** `response.interrupted?` returns `true`, `response.interrupt_reason` is `:max_steps`.
- **Streaming:** Yields an `Interrupt` event with `reason: :max_steps`.
- **Resumable:** Yes. Call `generate('Continue')` or `stream('Continue')` on the same agent instance to resume. For cross-process resume, pass persisted messages as an array to a new agent. Pending tool calls are automatically executed before the LLM loop resumes.

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  max_steps 8
end

response = MyAgent.generate('Do a complex task')
response.interrupted?      # => true (if 8 steps were reached)
response.interrupt_reason  # => :max_steps
```

### Unhandled Exceptions

If a guardrail, provider call, or other internal code raises an exception, it propagates to the caller. Tool execution exceptions are the one exception — they are caught and sent back to the LLM as error messages (see [Error Handling](#error-handling) above).

### Comparison

|               | Guardrail Tripwire                   | Callback Interrupt                   | Max Steps Limit                      |
| ------------- | ------------------------------------ | ------------------------------------ | ------------------------------------ |
| Defined       | At class level (`guardrail :before`) | At instance level (`on_message`)     | At class level (`max_steps 8`)       |
| Fires         | Automatically on every request       | When callback logic decides          | When step count reaches limit        |
| Resumable     | No                                   | Yes (call `generate`/`stream` again) | Yes (call `generate`/`stream` again) |
| Response flag | `blocked?`                           | `interrupted?`                       | `interrupted?`                       |
| Stream event  | `GuardrailTripwire`                  | `Interrupt`                          | `Interrupt`                          |
| Purpose       | Policy enforcement                   | Flow control                         | Runaway loop prevention              |

## Timing

`Riffer::Agent::Response#duration` (seconds, `Float`) reports the **total run time** for `generate` — from the start of the loop through the final response. It's measured with a monotonic clock and is **always populated**, regardless of `Riffer.config.report_timings`. (Streaming returns an `Enumerator`, not a `Response`, so time your own iteration there.)

```ruby
response = MyAgent.generate("Hello")
puts "Took #{response.duration.round(3)}s"
```

Set `Riffer.config.report_timings = true` to also collect a per-call breakdown. Each LLM call in the loop produces a `:llm`-kind entry in `response.timings`:

```ruby
Riffer.config.report_timings = true
response = MyAgent.generate("Plan a trip")

response.timings.select { |t| t.kind == :llm }.each do |timing|
  line = "step #{timing.step} (#{timing.model}): #{timing.duration_ms.round(2)}ms"
  line += " — first token at #{timing.ttft_ms.round(2)}ms" if timing.ttft
  puts line
end
```

Each `Riffer::Providers::Timing` exposes `model`, `step` (which loop iteration produced the call), `duration`/`duration_ms`, and — for **streamed** calls — `ttft`/`ttft_ms`, the time to first token (the first generated text, reasoning, or tool-call delta). `ttft` is `nil` for non-streaming `generate`.

These `:llm` timings interleave with `:guardrail` and `:tool` timings in `response.timings`, in execution order. See [Configuration — Timing Reporting](10_CONFIGURATION.md#timing-reporting) for the full model.
