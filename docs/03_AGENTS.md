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
  model 'test/any'                # Test provider
end
```

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
  model_options reasoning: 'medium', temperature: 0.7
end
```

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
  guardrail :around, with: Riffer::Guardrails::MaxLength, max: 1000
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

**Resuming** — use `resume` (or `resume_stream`) to continue an interrupted loop:

```ruby
agent = MyAgent.new
agent.on_message { |msg| throw :riffer_interrupt if needs_approval?(msg) }

response = agent.generate('Do something risky')

if response.interrupted?
  approve_action(agent.messages)
  response = agent.resume
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

When called without `messages:`, both methods raise `Riffer::ArgumentError` if the agent was not previously interrupted. When called with `messages:`, no prior interruption is required.

**Note:** If a callback throws during tool execution (after processing some but not all tool calls), the conversation will have partial tool results. To avoid this, check the message type before throwing (e.g., only throw on `Riffer::Messages::Assistant`).

### resume

Continues an interrupted agent loop synchronously. Returns a `Riffer::Agent::Response` object.

When called without arguments, resumes from the agent's in-memory state (requires a prior interruption):

```ruby
agent = MyAgent.new
agent.on_message { |msg| throw :riffer_interrupt if needs_approval?(msg) }

response = agent.generate('Do something risky')

if response.interrupted?
  approve_action(agent.messages)
  response = agent.resume
end
```

For cross-process resume (e.g., after a process restart or async approval), pass persisted messages via the `messages:` keyword. Accepts both message objects and hashes:

```ruby
agent = MyAgent.new
response = agent.resume(messages: persisted_messages, tool_context: {user_id: 123})
```

When called without `messages:`, raises `Riffer::ArgumentError` if the agent was not previously interrupted. When called with `messages:`, no prior interruption is required.

### resume_stream

Continues an interrupted agent loop as a streaming Enumerator. Accepts the same arguments as `resume`:

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
