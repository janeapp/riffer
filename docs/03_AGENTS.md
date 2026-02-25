# Agents

Agents are the central orchestrator in Riffer. They manage the conversation flow, call LLM providers, and handle tool execution.

## Defining an Agent

Create an agent by subclassing `Riffer::Agent`:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  instructions 'You are a helpful assistant.'
end
```

## Configuration Methods

### model

Sets the provider and model in `provider/model` format:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'           # OpenAI
  # or
  model 'amazon_bedrock/anthropic.claude-3-sonnet-20240229-v1:0'  # Bedrock
  # or
  model 'mock/any'                # Mock provider
end
```

Models can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model -> { "anthropic/claude-sonnet-4-20250514" }
end
```

When the lambda accepts a parameter, it receives the `tool_context`:

```ruby
class MyAgent < Riffer::Agent
  model ->(ctx) {
    ctx&.dig(:premium) ? "anthropic/claude-sonnet-4-20250514" : "anthropic/claude-haiku-4-5-20251001"
  }
end
```

The lambda is re-evaluated on each `generate` or `stream` call, so the model can change between calls based on runtime context.

### instructions

Sets system instructions for the agent:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  instructions 'You are an expert Ruby programmer. Provide concise answers.'
end
```

### identifier

Sets a custom identifier (defaults to snake_case class name):

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  identifier 'custom_agent_name'
end

MyAgent.identifier  # => "custom_agent_name"
```

### uses_tools

Registers tools the agent can use:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  uses_tools [WeatherTool, TimeTool]
end
```

Tools can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'

  uses_tools ->(context) {
    tools = [PublicTool]
    tools << AdminTool if context&.dig(:user)&.admin?
    tools
  }
end
```

### provider_options

Passes options to the provider client:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  provider_options api_key: ENV['CUSTOM_OPENAI_KEY']
end
```

### model_options

Passes options to each LLM request:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  model_options reasoning: 'medium', temperature: 0.7, web_search: true
end
```

### max_steps

Sets the maximum number of LLM call steps in the tool-use loop. When the limit is reached, the loop interrupts with reason `:max_steps`. Defaults to `16`. Set to `Float::INFINITY` for unlimited steps:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  max_steps 8
end
```

### structured_output

Configures the agent to return structured JSON responses conforming to a schema. Accepts a `Riffer::Params` instance or a block DSL:

```ruby
class SentimentAgent < Riffer::Agent
  model 'openai/gpt-4o'
  instructions 'Analyze the sentiment of the given text.'
  structured_output do
    required :sentiment, String, description: "positive, negative, or neutral"
    required :score, Float, description: "Confidence score between 0 and 1"
    optional :explanation, String, description: "Brief explanation"
  end
end
```

The LLM response is automatically parsed and validated against the schema. Access the result via `response.structured_output`.

Structured output is not compatible with streaming — calling `stream` on an agent with structured output configured raises `Riffer::ArgumentError`.

### guardrail

Registers guardrails for pre/post processing of messages. Pass the guardrail class and any options:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'

  # Input-only guardrail
  guardrail :before, with: InputValidator

  # Output-only guardrail
  guardrail :after, with: ResponseFilter

  # Both input and output, with options
  guardrail :around, with: MaxLengthGuardrail, max: 1000
end
```

See [Guardrails](09_GUARDRAILS.md) for detailed documentation.

## Instance Methods

### generate

Generates a response synchronously. Returns a `Riffer::Agent::Response` object:

```ruby
# Class method (recommended for simple calls)
response = MyAgent.generate('Hello')
puts response.content       # Access the response text
puts response.blocked?      # Check if guardrail blocked (always false without guardrails)
puts response.interrupted?  # Check if a callback interrupted the loop

# Instance method (when you need message history or callbacks)
agent = MyAgent.new
agent.on_message { |msg| log(msg) }
response = agent.generate('Hello')
agent.messages  # Access message history

# With message objects/hashes
response = MyAgent.generate([
  {role: 'user', content: 'Hello'},
  {role: 'assistant', content: 'Hi there!'},
  {role: 'user', content: 'How are you?'}
])

# With tool context
response = MyAgent.generate('Look up my orders', tool_context: {user_id: 123})

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

Streams a response as an Enumerator:

```ruby
# Class method (recommended for simple calls)
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

# Instance method (when you need message history or callbacks)
agent = MyAgent.new
agent.on_message { |msg| persist_message(msg) }
agent.stream('Tell me a story').each { |event| handle(event) }
agent.messages  # Access message history

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

#### Interrupting the Agent Loop

Callbacks can interrupt the agent loop using Ruby's `throw`/`catch` pattern. This is useful for human-in-the-loop approval, cost limits, or content filtering.

Use `throw :riffer_interrupt` to stop the loop. The response will have `interrupted?` set to `true` and contain the accumulated content up to the point of interruption.

An optional reason can be passed as the second argument to `throw`. It is available via `interrupt_reason` on the response (generate) or `reason` on the `Interrupt` event (stream):

```ruby
agent = MyAgent.new
agent.on_message do |msg|
  if msg.is_a?(Riffer::Messages::Tool)
    throw :riffer_interrupt, "needs human approval"
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

#### Resuming an Interrupted Loop

Use `resume` (or `resume_stream`) to continue after an interrupt. On resume, the agent automatically detects and executes any pending tool calls (tool calls from the last assistant message that lack a corresponding tool result) before re-entering the LLM loop.

```ruby
agent = MyAgent.new
agent.on_message { |msg| throw :riffer_interrupt if needs_approval?(msg) }

response = agent.generate('Do something risky')

if response.interrupted?
  approve_action(agent.messages)
  response = agent.resume   # executes pending tools, then calls the LLM
end
```

For cross-process resume (e.g., after a process restart or async approval), pass persisted messages via the `messages:` keyword. Accepts both message objects and hashes:

```ruby
# Persist messages during generation (e.g., via on_message callback)
# Later, in a new process:
agent = MyAgent.new
response = agent.resume(messages: persisted_messages, tool_context: {user_id: 123})

# Or resume in streaming mode:
agent.resume_stream(messages: persisted_messages).each do |event|
  # handle stream events
end
```

When called without `messages:`, resumes from in-memory state. When called with `messages:`, reconstructs state from persisted data. No prior interruption is required in either case.

### resume

Continues an agent loop synchronously. Returns a `Riffer::Agent::Response` object:

```ruby
# In-memory resume after an interrupt
response = agent.resume

# Cross-process resume from persisted messages
response = agent.resume(messages: persisted_messages, tool_context: {user_id: 123})
```

### resume_stream

Continues an agent loop as a streaming Enumerator. Accepts the same arguments as `resume`:

```ruby
# In-memory resume
agent.resume_stream.each do |event|
  # handle stream events
end

# Cross-process resume
agent = MyAgent.new
agent.resume_stream(messages: persisted_messages).each do |event|
  # handle stream events
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

`Riffer::Agent::Response` is returned by `generate` and `resume`:

| Attribute          | Type                        | Description                                        |
| ------------------ | --------------------------- | -------------------------------------------------- |
| `content`          | `String`                    | The response text                                  |
| `structured_output` | `Hash` / `nil`              | Parsed and validated structured output (see below) |
| `blocked?`         | `Boolean`                   | `true` if a guardrail tripwire fired               |
| `tripwire`         | `Tripwire` / `nil`          | The guardrail tripwire that blocked the request    |
| `modified?`        | `Boolean`                   | `true` if a guardrail modified the content         |
| `modifications`    | `Array`                     | List of guardrail modifications applied            |
| `interrupted?`     | `Boolean`                   | `true` if the loop was interrupted                 |
| `interrupt_reason` | `String` / `Symbol` / `nil` | The reason passed to `throw :riffer_interrupt`     |

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

See [Messages — Structured Output on Messages](05_MESSAGES.md#structured-output-on-messages) for details.

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

## Tool Execution Flow

When an agent receives a response with tool calls:

1. Agent detects `tool_calls` in the assistant message
2. For each tool call:
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
  model 'openai/gpt-4o'
  guardrail :before, with: ContentPolicy
end

response = MyAgent.generate('blocked input')
response.blocked?          # => true
response.tripwire.reason   # => "Content policy violation"
```

### Callback Interrupt (imperative, external)

Callbacks registered with `on_message` can call `throw :riffer_interrupt` to pause the loop at any point — after receiving an assistant message, after a tool result, etc. The caller controls exactly when and why to interrupt.

- **When to use:** Flow control that depends on runtime decisions — human-in-the-loop approval, budget tracking, conditional pausing.
- **Response:** `response.interrupted?` returns `true`, `response.interrupt_reason` contains the optional reason.
- **Streaming:** Yields an `Interrupt` event with a `reason` attribute.
- **Resumable:** Yes. Call `resume` or `resume_stream` to continue. Pending tool calls are automatically executed before the LLM loop resumes.

```ruby
agent = MyAgent.new
agent.on_message do |msg|
  throw :riffer_interrupt, "approval needed" if requires_approval?(msg)
end

response = agent.generate('Do something risky')
response.interrupted?      # => true
response.interrupt_reason  # => "approval needed"
response = agent.resume    # continues where it left off
```

### Max Steps Limit

The `max_steps` class method caps the number of LLM call steps in the tool-use loop. When the step count reaches the limit, the loop interrupts automatically with reason `:max_steps`.

- **When to use:** Safety net to prevent runaway tool-use loops — useful when agents have access to many tools or operate autonomously.
- **Response:** `response.interrupted?` returns `true`, `response.interrupt_reason` is `:max_steps`.
- **Streaming:** Yields an `Interrupt` event with `reason: :max_steps`.
- **Resumable:** Yes. Call `resume` or `resume_stream` to continue. Pending tool calls are automatically executed before the LLM loop resumes.

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  max_steps 8
end

response = MyAgent.generate('Do a complex task')
response.interrupted?      # => true (if 8 steps were reached)
response.interrupt_reason  # => :max_steps
```

### Unhandled Exceptions

If a guardrail, provider call, or other internal code raises an exception, it propagates to the caller. Tool execution exceptions are the one exception — they are caught and sent back to the LLM as error messages (see [Error Handling](#error-handling) above).

### Comparison

|               | Guardrail Tripwire                   | Callback Interrupt               | Max Steps Limit                  |
| ------------- | ------------------------------------ | -------------------------------- | -------------------------------- |
| Defined       | At class level (`guardrail :before`) | At instance level (`on_message`) | At class level (`max_steps 8`)   |
| Fires         | Automatically on every request       | When callback logic decides      | When step count reaches limit    |
| Resumable     | No                                   | Yes (`resume` / `resume_stream`) | Yes (`resume` / `resume_stream`) |
| Response flag | `blocked?`                           | `interrupted?`                   | `interrupted?`                   |
| Stream event  | `GuardrailTripwire`                  | `Interrupt`                      | `Interrupt`                      |
| Purpose       | Policy enforcement                   | Flow control                     | Runaway loop prevention          |
