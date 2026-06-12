# Agent Lifecycle

## Construction

### Agent.new

```ruby
Agent.new(session: nil, context: nil)
```

- **`session:`** — an existing `Riffer::Agent::Session`. When given, the agent uses it as-is (no system/skills seeding). Typical use case: cross-process resume from persisted history. With `Riffer.config.experimental_history_healing` on, a provided session is healed at construction time so the `tool_use` ↔ `tool_result` invariant holds before the next inference call.
- **`context:`** — a `Hash` carried for the lifetime of the agent. Used to evaluate Proc-based `instructions`, `model`, `uses_tools`, and skill activation at construction time, and threaded through tool execution and guardrails on every `generate`/`stream` call.

When `session:` is omitted, the agent constructs a fresh session and seeds it with `[instruction_message, skills_message].compact` eagerly. To swap context, construct a new agent — context is fixed for the lifetime of an agent instance.

## Instance Methods

### generate

Generates a response synchronously. Returns a `Riffer::Agent::Response` object.

```ruby
agent.generate(prompt = nil, files: nil)
```

- **`prompt`** — when given, a new `Riffer::Messages::User` is silently appended to the session (no `on_message` callbacks fire for user inputs) and the inference loop runs.
- **`prompt` omitted** — the loop runs against the current session. Useful when the seeded session's last turn is already a user message, or when picking up pending tool calls from a prior interrupt.
- **`files:`** — requires `prompt`. Attached to the new user message.

```ruby
# New conversation (class method — recommended for simple calls)
response = MyAgent.generate('Hello', context: {user_id: 123})
puts response.content       # Access the response text
puts response.blocked?      # Check if guardrail blocked (always false without guardrails)
puts response.interrupted?  # Check if a callback interrupted the loop

# New conversation (instance method — when you need message history or callbacks)
agent = MyAgent.new(context: {user_id: 123})
agent.session.on_message { |msg| log(msg) }
response = agent.generate('Hello')
agent.session.messages  # Access message history

# Multi-turn conversation
agent = MyAgent.new
agent.generate('Hello')
agent.generate('Tell me more')   # continues with full history

# Resume from persisted messages (cross-process)
session = Riffer::Agent::Session.new(messages: persisted_messages)
agent = MyAgent.new(session: session, context: {user_id: 123})
response = agent.generate  # no prompt — session already has the last user message

# With files
response = MyAgent.generate('What is in this image?', files: [
  {data: base64_data, media_type: 'image/jpeg'}
])
```

### stream

Streams a response as an Enumerator. Same prompt/files semantics as `generate`.

```ruby
# New conversation (class method — recommended for simple calls)
MyAgent.stream('Tell me a story').each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::TextDone
    puts "\n"
  when Riffer::StreamEvents::ToolCallDone
    puts "[Tool: #{event.name}]"
  end
end

# New conversation (instance method — when you need message history or callbacks)
agent = MyAgent.new
agent.session.on_message { |msg| persist_message(msg) }
agent.stream('Tell me a story').each { |event| handle(event) }
agent.session.messages  # Access message history

# Multi-turn conversation
agent = MyAgent.new
agent.stream('Hello').each { |event| handle(event) }
agent.stream('Tell me more').each { |event| handle(event) }

# With files
MyAgent.stream('What is in this image?', files: [{data: base64_data, media_type: 'image/jpeg'}]).each do |event|
  print event.content if event.is_a?(Riffer::StreamEvents::TextDelta)
end
```

### session

Conversation state lives on `agent.session` — a `Riffer::Agent::Session` instance that owns the message array, the `on_message` callback list, and the `tool_use` ↔ `tool_result` invariant. The methods below are all on the session, not on the agent itself.

Access the message history after a generate/stream call:

```ruby
agent = MyAgent.new
agent.generate('Hello')

agent.session.messages.each do |msg|
  puts "#{msg.role}: #{msg.content}"
end
```

`Riffer::Agent::Session` includes `Enumerable`, so `find`, `select`, `count`, `reverse_each` all work directly on the session:

```ruby
agent.session.find { |m| m.id == 'a_1' }
agent.session.count { |m| m.is_a?(Riffer::Messages::Assistant) }
```

### on_message

Registers a callback to receive messages as they're added during generation:

```ruby
agent.session.on_message do |message|
  case message.role
  when :assistant
    puts "[Assistant] #{message.content}"
  when :tool
    puts "[Tool:#{message.name}] #{message.content}"
  end
end
```

Multiple callbacks can be registered. Returns `self` for method chaining:

```ruby
agent.session
  .on_message { |msg| persist_message(msg) }
  .on_message { |msg| log_message(msg) }
agent.generate('Hello')
```

Works with both `generate` and `stream`. Only emits agent-generated messages (Assistant, Tool), not inputs (System, User).

## Interrupting the Agent Loop

Callbacks can interrupt the agent loop. This is useful for human-in-the-loop approval, cost limits, or content filtering.

Use `agent.interrupt!` (or the lower-level `throw :riffer_interrupt`) to stop the loop. The response will have `interrupted?` set to `true` and contain the accumulated content up to the point of interruption.

An optional reason can be passed to `interrupt!`. It is available via `interrupt_reason` on the response (generate) or `reason` on the `Interrupt` event (stream):

```ruby
agent = MyAgent.new
agent.session.on_message do |msg|
  if msg.is_a?(Riffer::Messages::Tool)
    agent.interrupt!("needs human approval")
  end
end

response = agent.generate('Call the tool')
response.interrupted?      # => true
response.interrupt_reason  # => "needs human approval"
response.content           # => last assistant content before interrupt
```

**Streaming** — interrupts emit an `Interrupt` event:

```ruby
agent = MyAgent.new
agent.session.on_message { |msg| throw :riffer_interrupt, "budget exceeded" }

agent.stream('Hello').each do |event|
  case event
  when Riffer::StreamEvents::Interrupt
    puts "Loop was interrupted: #{event.reason}"
  end
end
```

**Partial tool execution** — tool calls are executed one at a time. When an interrupt fires during tool execution, only the completed tool results remain in the message history. For example, if an assistant message requests two tool calls and the callback interrupts after the first tool result, only that first result will be in the message history.

### Resuming an Interrupted Loop

There are two ways to resume after an interrupt, depending on whether the agent is still in memory or you're restoring from persisted data.

**In-memory resume** — call `generate` (or `stream`) again. With a prompt, the new user message is appended and the loop runs. Without a prompt, the loop runs against the current session — useful for picking up pending tool calls after the user has approved.

```ruby
agent = MyAgent.new(context: {user_id: 123})
agent.session.on_message { |msg| throw :riffer_interrupt if needs_approval?(msg) }

response = agent.generate('Do something risky')

if response.interrupted?
  approve_action(agent.session.messages)
  response = agent.generate('Approved, go ahead')  # executes pending tools, then calls the LLM
  # or: agent.generate                              # resume without a new turn
end
```

**Cross-process resume** — when the agent is gone (process restart, async approval, etc.), construct a `Riffer::Agent::Session` from the persisted messages and pass it to a new agent. The agent uses the session as-is (no system messages added). Pending tool calls on the resume boundary are executed on the next `generate`/`stream`.

```ruby
# During generation, persist each new message via on_message
# Later, in a new process:
session = Riffer::Agent::Session.new(messages: persisted_messages)
agent = MyAgent.new(session: session, context: {user_id: 123})
response = agent.generate  # session already has the last user turn

# Or resume in streaming mode:
agent = MyAgent.new(session: session, context: {user_id: 123})
agent.stream.each do |event|
  # handle stream events
end
```

### Reading System Messages for Persistence

Read the agent's instruction and skills system messages from `agent.instruction_message` and `agent.skills_message`. Both are built once at `Agent.new` time using the constructor `context:` and cached — they reflect the agent's configured `instructions` and `skills` DSL output. Useful for database persistence workflows where you need to store and later reconstruct message histories.

Both return `Riffer::Messages::System` or `nil` (when unconfigured / empty).

```ruby
agent = MyAgent.new(context: ctx)
sys = agent.instruction_message     # => Riffer::Messages::System or nil
skills = agent.skills_message       # => Riffer::Messages::System or nil

# Store in DB, then later resume in a new process:
session = Riffer::Agent::Session.new(messages: [sys, skills, user_msg].compact)
MyAgent.new(session: session, context: ctx).generate
```

### interrupt!

Interrupts the agent loop from an `on_message` callback. Equivalent to `throw :riffer_interrupt, reason`:

```ruby
agent.session.on_message do |msg|
  agent.interrupt!(:needs_approval) if requires_approval?(msg)
end
```

#### Healing pending tool results on interrupt (experimental)

When an interrupt fires while the assistant has a `tool_use` block that hasn't been answered yet, the LLM will reject the next request unless every `tool_use` has a matching `tool_result`. By default, the next `generate` call re-executes those pending tools (see "Resuming an Interrupted Loop" above).

When the interrupt represents a course-change rather than a pause — e.g. a voice barge-in where the user has moved on — re-execution is the wrong behavior. Opt into history healing to have riffer fill any orphan `tool_use` with a placeholder `Riffer::Messages::Tool` carrying `error_type: :interrupted`, leaving history valid for the next turn:

```ruby
Riffer.configure { |c| c.experimental_history_healing = true }

agent.session.on_message do |msg|
  agent.interrupt!(:user_interrupt) if msg.is_a?(Riffer::Messages::Assistant) && barge_in?
end

response = agent.generate("Tell me a story")
response.healed_tool_call_ids  # => ["call_abc123", ...]
```

The placeholder content is fixed: `"Tool call interrupted before completion."` with `error_type: :interrupted`. Each placeholder is inserted immediately after its parent assistant message. The list of filled `call_id`s is exposed on `response.healed_tool_call_ids` (and on `Riffer::StreamEvents::Interrupt#healed_tool_call_ids` when streaming).

Healing covers all interrupts uniformly — caller-issued `interrupt!` and the built-in `INTERRUPT_MAX_STEPS` ceiling alike. When the flag is off (the default), orphans remain in history and `execute_pending_tool_calls` re-runs them on the next `generate` call.

If you need finer control over placeholder content (per-call shape, structured metadata, etc.), use the `update` mutator below to upgrade a placeholder after the interrupt returns.

### Mutating history

The session exposes a small set of in-place mutators that enforce the `tool_use` ↔ `tool_result` invariant on every operation. Use these to align history with external state (persisted transcript, partial output that wasn't actually delivered, etc.) without rebuilding the agent.

- **`agent.session.update(id:, **attrs)`** — In-place partial update. Looks up by message `id:`; builds a replacement of the same type with `attrs` overlaid on the existing fields. Use this to edit assistant content (`update(id:, content:)`), restate a system message, etc. When the target is an assistant and the update drops entries from `tool_calls`, matching `Tool` children are removed atomically.
- **`agent.session.update(tool_call_id:, **attrs)`** — Same as above but looks up the tool result by `tool_call_id:`. Preserves `name` and `id`. Use this to upgrade an interrupt-time placeholder once the real result is available (`update(tool_call_id:, content:, error: nil, error_type: nil)`).
- **`agent.session.remove(id:)`** — Removes a message; cascades to its `Tool` children when the target carries `tool_calls`. Raises if called on a `Tool` message (use `update(tool_call_id:, ...)` to rewrite a tool result instead).

Bulk filling of orphan `tool_use` blocks is handled by `Riffer.config.experimental_history_healing` (see "Healing pending tool results on interrupt" above) — there is no public synthesizer hook.

Lookup patterns that pair with the mutators (via `Enumerable`):

```ruby
agent.session.find { |m| m.id == id }                                           # message by id
agent.session.reverse_each.find { |m| m.is_a?(Riffer::Messages::Tool) && m.tool_call_id == call_id }
agent.session.reverse_each.find { |m| m.is_a?(Riffer::Messages::Assistant) }    # last assistant
agent.session.orphaned_tool_call_ids                                            # Array[String], zero-cost validation
```

Mutating history while a `stream` enumerator is being consumed is undefined; mutators are intended for use between turns.

Mutators do **not** fire `on_message` — that callback is reserved for messages produced by inference (LLM responses, tool execution results). Healing placeholders bypass `on_message` for the same reason; consumers learn that healing happened via `Response#healed_tool_call_ids` (and `StreamEvents::Interrupt#healed_tool_call_ids`).

### context

The mutable runtime context. A `Hash` threaded into every Proc-based DSL setting, guardrail, tool runtime, and skills resolution, and shared with every `Riffer::Agent::Run` this agent executes. Carries:

- `context[:skills]` — the resolved `Riffer::Skills::Context` when skills are configured.
- `context[:token_usage]` — the cumulative `Riffer::Providers::TokenUsage`, mutated by each Run as the loop progresses. Per-run totals are on `response.token_usage`.
- any caller-provided keys passed via `Agent.new(context: ...)`.

```ruby
agent = MyAgent.new
agent.generate("Hello!")

agent.context[:token_usage]   # cumulative TokenUsage across all calls
agent.context[:skills]        # the Skills::Context, if skills configured
```

## Response Attributes

`Riffer::Agent::Response` is returned by `generate`:

| Attribute              | Type                        | Description                                                                                      |
| ---------------------- | --------------------------- | ------------------------------------------------------------------------------------------------ |
| `content`              | `String`                    | The response text                                                                                |
| `structured_output`    | `Hash` / `nil`              | Parsed and validated structured output (see below)                                               |
| `blocked?`             | `Boolean`                   | `true` if a guardrail tripwire fired                                                             |
| `tripwire`             | `Tripwire` / `nil`          | The guardrail tripwire that blocked the request                                                  |
| `modified?`            | `Boolean`                   | `true` if a guardrail modified the content                                                       |
| `modifications`        | `Array`                     | List of guardrail modifications applied                                                          |
| `interrupted?`         | `Boolean`                   | `true` if the loop was interrupted                                                               |
| `interrupt_reason`     | `String` / `Symbol` / `nil` | The reason passed to `throw :riffer_interrupt`                                                   |
| `messages`             | `Array`                     | Full message history from the conversation                                                       |
| `healed_tool_call_ids` | `Array[String]`             | `tool_call` ids filled with placeholder results during interrupt healing (else `[]`)             |
| `token_usage`          | `TokenUsage` / `nil`        | Aggregate `Riffer::Providers::TokenUsage` across this run's LLM calls (`nil` when none reported) |

### response.structured_output

When structured output is configured, the LLM response is parsed as JSON and validated against the schema. The validated result is available as `response.structured_output`:

```ruby
response = SentimentAgent.generate('Analyze: "I love this!"')
response.content            # => raw JSON string from the LLM
response.structured_output  # => {sentiment: "positive", score: 0.95}
```

Returns `nil` when structured output is not configured or when validation fails.

The assistant message in the message history stores the parsed hash, so you can access structured output directly from persisted messages:

```ruby
agent = SentimentAgent.new
agent.generate('Analyze: "I love this!"')

msg = agent.session.messages.last
msg.structured_output?    # => true
msg.structured_output     # => {sentiment: "positive", score: 0.95}
```

See [Messages — Structured Output on Messages](08_MESSAGES.md#structured-output-on-messages) for details.

## Class Methods

### find

Find an agent class by identifier:

```ruby
agent_class = Riffer::Agent.find('my_agent')
agent = agent_class.new
```

### all

List all agent subclasses:

```ruby
Riffer::Agent.all.each do |agent_class|
  puts agent_class.identifier
end
```
