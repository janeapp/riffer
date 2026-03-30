# Agent Lifecycle

## Instance Methods

### generate

Generates a response synchronously. Returns a `Riffer::Agent::Response` object.

The behavior depends on what you pass and the agent's current state:

| Input      | Agent state                    | Behavior                                                                                                                                                              |
| ---------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **String** | No prior messages              | **New conversation.** Builds system messages (instructions + skills), adds user message, calls the LLM.                                                               |
| **String** | Has messages from a prior call | **Continue conversation.** Appends the user message to the existing history and re-enters the LLM loop. Pending tool calls from a prior interrupt are executed first. |
| **Array**  | No prior messages              | **Restore from persisted data.** Uses the array as-is (no system messages added). Pending tool calls are executed. This is for cross-process resume.                  |
| **Array**  | Has messages from a prior call | **Raises `Riffer::ArgumentError`.** Use a string to continue, or a new agent instance to start from a persisted array.                                                |

**State reset per call:** Each call to `generate` or `stream` resets `context`, tools, tool runtime, model, skills state, and the interrupted flag. This means `context:` must be passed on every call — it is not carried over from a previous call. The only state that persists across calls is the message history and cumulative `token_usage`.

```ruby
agent.generate('Hello', context: {user_id: 123})
agent.generate('Follow up')  # context is nil here — pass it again if needed
agent.generate('More', context: {user_id: 123})  # context is restored
```

```ruby
# New conversation (class method — recommended for simple calls)
response = MyAgent.generate('Hello')
puts response.content       # Access the response text
puts response.blocked?      # Check if guardrail blocked (always false without guardrails)
puts response.interrupted?  # Check if a callback interrupted the loop

# New conversation (instance method — when you need message history or callbacks)
agent = MyAgent.new
agent.on_message { |msg| log(msg) }
response = agent.generate('Hello')
agent.messages  # Access message history

# Multi-turn conversation
agent = MyAgent.new
agent.generate('Hello')
agent.generate('Tell me more')   # continues with full history

# Restore from persisted messages (cross-process resume)
agent = MyAgent.new
response = agent.generate(persisted_messages, context: {user_id: 123})

# With context
response = MyAgent.generate('Look up my orders', context: {user_id: 123})

# With files (string prompt + files shorthand)
response = MyAgent.generate('What is in this image?', files: [
  {data: base64_data, media_type: 'image/jpeg'}
])

# With files in messages array (per-message)
response = MyAgent.generate([
  {role: 'user', content: 'Describe this document', files: [
    {url: 'https://example.com/report.pdf', media_type: 'application/pdf'}
  ]}
])
```

### stream

Streams a response as an Enumerator. Follows the same input rules as `generate` — a string starts a new conversation or continues an existing one, an array restores from persisted data.

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
agent.on_message { |msg| persist_message(msg) }
agent.stream('Tell me a story').each { |event| handle(event) }
agent.messages  # Access message history

# Multi-turn conversation
agent = MyAgent.new
agent.stream('Hello').each { |event| handle(event) }
agent.stream('Tell me more').each { |event| handle(event) }

# With files
MyAgent.stream('What is in this image?', files: [{data: base64_data, media_type: 'image/jpeg'}]).each do |event|
  print event.content if event.is_a?(Riffer::StreamEvents::TextDelta)
end
```

### messages

Access the message history after a generate/stream call:

```ruby
agent = MyAgent.new
agent.generate('Hello')

agent.messages.each do |msg|
  puts "#{msg.role}: #{msg.content}"
end
```

### on_message

Registers a callback to receive messages as they're added during generation:

```ruby
agent.on_message do |message|
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
agent
  .on_message { |msg| persist_message(msg) }
  .on_message { |msg| log_message(msg) }
  .generate('Hello')
```

Works with both `generate` and `stream`. Only emits agent-generated messages (Assistant, Tool), not inputs (System, User).

## Interrupting the Agent Loop

Callbacks can interrupt the agent loop. This is useful for human-in-the-loop approval, cost limits, or content filtering.

Use `agent.interrupt!` (or the lower-level `throw :riffer_interrupt`) to stop the loop. The response will have `interrupted?` set to `true` and contain the accumulated content up to the point of interruption.

An optional reason can be passed to `interrupt!`. It is available via `interrupt_reason` on the response (generate) or `reason` on the `Interrupt` event (stream):

```ruby
agent = MyAgent.new
agent.on_message do |msg|
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
agent.on_message { |msg| throw :riffer_interrupt, "budget exceeded" }

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

**In-memory resume** — call `generate` (or `stream`) again with a string. The agent keeps its message history, so a new string appends a user message and continues the loop. Pending tool calls from the interrupt are automatically executed first.

```ruby
agent = MyAgent.new
agent.on_message { |msg| throw :riffer_interrupt if needs_approval?(msg) }

response = agent.generate('Do something risky')

if response.interrupted?
  approve_action(agent.messages)
  response = agent.generate('Approved, go ahead')  # executes pending tools, then calls the LLM
end
```

You can also resume without adding a new user message by passing a continuation like `'Continue'` — the LLM will pick up from the existing context.

**Cross-process resume** — when the agent is gone (process restart, async approval, etc.), create a new agent and pass the persisted messages as an array. Array input uses messages as-is (no system messages added) and executes any pending tool calls.

```ruby
# During generation, persist messages via on_message callback
# Later, in a new process:
agent = MyAgent.new
response = agent.generate(persisted_messages, context: {user_id: 123})

# Or resume in streaming mode:
agent = MyAgent.new
agent.stream(persisted_messages).each do |event|
  # handle stream events
end
```

**Important:** You cannot pass an array to an agent that already has messages. This raises `Riffer::ArgumentError` because it would silently discard the existing history. Use a string to continue, or create a new agent instance for cross-process resume.

### Building System Messages for Persistence

Use `generate_instruction_message` and `generate_skills_message` to generate system messages independently. This is useful for database persistence workflows where you need to store and later reconstruct message histories.

Both methods return a `Riffer::Messages::System` or `nil` (when unconfigured). They accept an optional `context:` keyword, just like `generate`.

```ruby
agent = MyAgent.new
sys = agent.generate_instruction_message(context: ctx)     # => Riffer::Messages::System or nil
skills = agent.generate_skills_message(context: ctx)        # => Riffer::Messages::System or nil

# Store in DB, then later resume in a new process:
messages = [sys, skills, user_msg].compact
MyAgent.new.generate(messages, context: ctx)
```

### interrupt!

Interrupts the agent loop from an `on_message` callback. Equivalent to `throw :riffer_interrupt, reason`:

```ruby
agent.on_message do |msg|
  agent.interrupt!(:needs_approval) if requires_approval?(msg)
end
```

### token_usage

Access cumulative token usage across all LLM calls:

```ruby
agent = MyAgent.new
agent.generate("Hello!")

if agent.token_usage
  puts "Total tokens: #{agent.token_usage.total_tokens}"
  puts "Input: #{agent.token_usage.input_tokens}"
  puts "Output: #{agent.token_usage.output_tokens}"
end
```

Returns `nil` if the provider doesn't report usage, or a `Riffer::TokenUsage` object with accumulated totals.

## Response Attributes

`Riffer::Agent::Response` is returned by `generate`:

| Attribute           | Type                        | Description                                        |
| ------------------- | --------------------------- | -------------------------------------------------- |
| `content`           | `String`                    | The response text                                  |
| `structured_output` | `Hash` / `nil`              | Parsed and validated structured output (see below) |
| `blocked?`          | `Boolean`                   | `true` if a guardrail tripwire fired               |
| `tripwire`          | `Tripwire` / `nil`          | The guardrail tripwire that blocked the request    |
| `modified?`         | `Boolean`                   | `true` if a guardrail modified the content         |
| `modifications`     | `Array`                     | List of guardrail modifications applied            |
| `interrupted?`      | `Boolean`                   | `true` if the loop was interrupted                 |
| `interrupt_reason`  | `String` / `Symbol` / `nil` | The reason passed to `throw :riffer_interrupt`     |
| `messages`          | `Array`                     | Full message history from the conversation         |

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

msg = agent.messages.last
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
