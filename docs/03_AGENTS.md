# Agents

Agents are the central orchestrator in Riffer. They manage the conversation flow, call LLM providers, and handle tool execution.

## Defining an Agent

Create an agent by subclassing `Riffer::Agent`:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are a helpful assistant.'
end
```

## Configuration Methods

### model

Sets the provider and model in `provider/model` format:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'           # OpenAI
  # or
  model 'amazon_bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0'  # Bedrock
  # or
  model 'mock/any'                # Mock provider
end
```

Models can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model -> { "anthropic/claude-haiku-4-5-20251001" }
end
```

When the lambda accepts a parameter, it receives the `context`:

```ruby
class MyAgent < Riffer::Agent
  model ->(context) {
    context&.dig(:premium) ? "anthropic/claude-sonnet-4-5-20250929" : "anthropic/claude-haiku-4-5-20251001"
  }
end
```

The lambda is re-evaluated on each `generate` or `stream` call, so the model can change between calls based on runtime context.

### instructions

Sets system instructions for the agent:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are an expert Ruby programmer. Provide concise answers.'
end
```

Instructions can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions -> { "Today is #{Date.today}. You are a helpful assistant." }
end
```

When the lambda accepts a parameter, it receives the `context`:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions ->(ctx) { "You are assisting #{ctx[:name]}" }
end

MyAgent.generate('Hello!', context: { name: 'Jane' })
```

The lambda is re-evaluated on each `generate` or `stream` call, so instructions can change between calls based on runtime context.

### identifier

Sets a custom identifier (defaults to snake_case class name):

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  identifier 'custom_agent_name'
end

MyAgent.identifier  # => "custom_agent_name"
```

### uses_tools

Registers tools the agent can use:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, TimeTool]
end
```

Tools can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

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
  model 'openai/gpt-5-mini'
  provider_options api_key: ENV['CUSTOM_OPENAI_KEY']
end
```

### model_options

Passes options to each LLM request:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  model_options reasoning: 'medium', temperature: 0.7, web_search: true
end
```

### max_steps

Sets the maximum number of LLM call steps in the tool-use loop. When the limit is reached, the loop interrupts with reason `:max_steps`. Defaults to `16`. Set to `Float::INFINITY` for unlimited steps:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  max_steps 8
end
```

### structured_output

Configures the agent to return structured JSON responses conforming to a schema. Accepts a `Riffer::Params` instance or a block DSL:

```ruby
class SentimentAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'Analyze the sentiment of the given text.'
  structured_output do
    required :sentiment, String, description: "positive, negative, or neutral"
    required :score, Float, description: "Confidence score between 0 and 1"
    optional :explanation, String, description: "Brief explanation"
  end
end
```

The LLM response is automatically parsed and validated against the schema. Access the result via `response.structured_output`.

#### Nested Objects

Use `Hash` with a block to define nested object schemas:

```ruby
structured_output do
  required :name, String, description: "Person name"
  required :address, Hash, description: "Mailing address" do
    required :street, String, description: "Street address"
    required :city, String, description: "City"
    optional :postal_code, String, description: "Postal or zip code"
  end
end
```

Validation errors use dot-path notation: `address.city is required`.

#### Typed Arrays

Use `Array` with the `of:` keyword for arrays of primitive types:

```ruby
structured_output do
  required :tags, Array, of: String, description: "Tags"
  required :scores, Array, of: Float, description: "Scores"
end
```

Only primitive types are allowed with `of:`: `String`, `Integer`, `Float`, `TrueClass`, `FalseClass`.

#### Arrays of Objects

Use `Array` with a block to define arrays of objects:

```ruby
structured_output do
  required :items, Array, description: "Line items" do
    required :name, String, description: "Product name"
    required :price, Float, description: "Price"
    optional :quantity, Integer, description: "Quantity"
  end
end
```

Validation errors include the array index: `items[1].price is required`.

#### Deep Nesting

Blocks can be nested arbitrarily deep:

```ruby
structured_output do
  required :orders, Array, description: "Orders" do
    required :id, String, description: "Order ID"
    required :shipping, Hash, description: "Shipping info" do
      required :address, Hash, description: "Address" do
        required :street, String
        required :city, String
      end
    end
  end
end
```

#### Limitations

Using both `of:` and a block raises `Riffer::ArgumentError`. Using `of:` with a non-primitive type (e.g. `of: Hash`) also raises `Riffer::ArgumentError`.

Structured output is not compatible with streaming — calling `stream` on an agent with structured output configured raises `Riffer::ArgumentError`.

### tool_runtime (Experimental)

> **Warning:** This feature is experimental and may be removed or changed without warning in a future release.

Configures how tool calls are executed. Defaults to sequential (inline) execution:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime Riffer::ToolRuntime::Threaded
end
```

Accepts a `Riffer::ToolRuntime` subclass, a `Riffer::ToolRuntime` instance, or a `Proc`. Inherited by subclasses. When unset, falls back to `Riffer.config.tool_runtime`. See [Tools — Tool Runtime](04_TOOLS.md#tool-runtime-experimental) for details.

### guardrail

Registers guardrails for pre/post processing of messages. Pass the guardrail class and any options:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

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

#### Interrupting the Agent Loop

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

#### Resuming an Interrupted Loop

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

#### Building System Messages for Persistence

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
2. The configured tool runtime executes the tool calls (sequentially by default, or concurrently with `Riffer::ToolRuntime::Threaded`):
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
