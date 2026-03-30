# Agent Loop

## Tool Execution Flow

When an agent receives a response with tool calls:

1. Agent detects `tool_calls` in the assistant message
2. If the agent has subagents, agent-bound tool calls are dispatched separately — see [Agent Orchestration](14_AGENT_ORCHESTRATION.md)
3. The configured tool runtime executes the calls (sequentially by default, or concurrently with `Riffer::ToolRuntime::Threaded`):
   - Finds the matching tool class
   - Validates arguments against the tool's parameter schema
   - Calls the tool's `call` method with `context` and arguments
4. Creates Tool messages with the results
5. Sends the updated message history back to the LLM
6. Repeats until no more tool calls

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
agent.on_message do |msg|
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
