# Stream Events

When streaming responses, Riffer emits typed events that represent incremental updates from the LLM.

## Using Streaming

Use `stream` instead of `generate` to receive events as they arrive:

```ruby
agent = MyAgent.new

agent.stream("Tell me a story").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::TextDone
    puts "\n[Complete]"
  when Riffer::StreamEvents::ToolCallDelta
    # Tool call being built
  when Riffer::StreamEvents::ToolCallDone
    puts "[Tool: #{event.name}]"
  end
end
```

## Event Types

### TextDelta

Emitted when incremental text content is received:

```ruby
event = Riffer::StreamEvents::TextDelta.new("Hello ")
event.role     # => "assistant"
event.content  # => "Hello "
event.to_h     # => {role: "assistant", content: "Hello "}
```

Use this to display text in real-time as it streams.

### TextDone

Emitted when text generation is complete:

```ruby
event = Riffer::StreamEvents::TextDone.new("Hello, how can I help you?")
event.role     # => "assistant"
event.content  # => "Hello, how can I help you?"
event.to_h     # => {role: "assistant", content: "Hello, how can I help you?"}
```

Contains the complete final text.

### ToolCallDelta

Emitted when tool call arguments are being streamed:

```ruby
event = Riffer::StreamEvents::ToolCallDelta.new(
  item_id: "item_123",
  name: "weather_tool",
  arguments_delta: '{"city":'
)
event.role             # => "assistant"
event.item_id          # => "item_123"
event.name             # => "weather_tool"
event.arguments_delta  # => '{"city":'
```

The `name` may only be present in the first delta. Accumulate `arguments_delta` to build the complete arguments.

### ToolCallDone

Emitted when a tool call is complete:

```ruby
event = Riffer::StreamEvents::ToolCallDone.new(
  item_id: "item_123",
  call_id: "call_456",
  name: "weather_tool",
  arguments: '{"city":"Tokyo"}'
)
event.role       # => "assistant"
event.item_id    # => "item_123"
event.call_id    # => "call_456"
event.name       # => "weather_tool"
event.arguments  # => '{"city":"Tokyo"}'
```

Contains the complete tool call information.

### ReasoningDelta

Emitted when reasoning/thinking content is streamed (OpenAI with reasoning enabled):

```ruby
event = Riffer::StreamEvents::ReasoningDelta.new("Let me think about ")
event.role     # => "assistant"
event.content  # => "Let me think about "
```

### ReasoningDone

Emitted when reasoning is complete:

```ruby
event = Riffer::StreamEvents::ReasoningDone.new("Let me think about this step by step...")
event.role     # => "assistant"
event.content  # => "Let me think about this step by step..."
```

### GuardrailTripwire

Emitted when a guardrail blocks execution during streaming:

```ruby
agent.stream("Hello").each do |event|
  case event
  when Riffer::StreamEvents::GuardrailTripwire
    puts "Blocked by: #{event.guardrail_id}"
    puts "Reason: #{event.reason}"
    puts "Phase: #{event.phase}"  # :before or :after
  end
end
```

See [Guardrails](09_GUARDRAILS.md) for more information.

### GuardrailModification

Emitted when a guardrail transforms data during streaming:

```ruby
agent.stream("Hello").each do |event|
  case event
  when Riffer::StreamEvents::GuardrailModification
    puts "Modified by: #{event.guardrail_id}"
    puts "Phase: #{event.phase}"              # :before or :after
    puts "Changed: #{event.message_indices}"  # Array of affected indices
  end
end
```

See [Guardrails](09_GUARDRAILS.md) for more information.

### Interrupt

Emitted when an `on_message` callback interrupts the agent loop via `throw :riffer_interrupt`. This is the streaming equivalent of `Response#interrupted?` in generate mode.

```ruby
event = Riffer::StreamEvents::Interrupt.new(reason: "needs approval")
event.role    # => :system
event.reason  # => "needs approval"
event.to_h    # => {role: :system, interrupt: true, reason: "needs approval"}
```

The `reason` is `nil` when `throw :riffer_interrupt` is called without a second argument.

```ruby
agent.stream("Hello").each do |event|
  case event
  when Riffer::StreamEvents::Interrupt
    puts "Loop was interrupted: #{event.reason}"
  end
end
```

After an interrupt, use `resume_stream` to continue the loop. See [Agents - Interrupting the Agent Loop](03_AGENTS.md#interrupting-the-agent-loop) for details.

### TokenUsageDone

Emitted when token usage data is available at the end of a response:

```ruby
event = Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage)
event.role                          # => :assistant
event.token_usage                   # => Riffer::TokenUsage
event.token_usage.input_tokens      # => 100
event.token_usage.output_tokens     # => 50
event.token_usage.total_tokens      # => 150
event.to_h                          # => {role: :assistant, token_usage: {input_tokens: 100, output_tokens: 50}}
```

Use this to track token consumption in real-time during streaming.

## Streaming with Tools

When an agent uses tools during streaming, the flow is:

1. Text events stream in (`TextDelta`, `TextDone`)
2. If tool calls are present: `ToolCallDelta` events, then `ToolCallDone`
3. Agent executes tools internally
4. Agent sends results back to LLM
5. More text events stream in
6. Repeat until no more tool calls

```ruby
agent.stream("What's the weather in Tokyo?").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::ToolCallDone
    puts "\n[Calling #{event.name}...]"
  when Riffer::StreamEvents::TextDone
    puts "\n"
  end
end
```

## Complete Example

```ruby
class WeatherAgent < Riffer::Agent
  model 'openai/gpt-4o'
  instructions 'You are a weather assistant.'
  uses_tools [WeatherTool]
end

agent = WeatherAgent.new
text_buffer = ""

agent.stream("What's the weather in Tokyo and New York?").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
    text_buffer += event.content

  when Riffer::StreamEvents::TextDone
    # Final text available
    puts "\n---"
    puts "Complete response: #{event.content}"

  when Riffer::StreamEvents::ToolCallDelta
    # Could show "typing..." indicator

  when Riffer::StreamEvents::ToolCallDone
    puts "\n[Tool: #{event.name}(#{event.arguments})]"

  when Riffer::StreamEvents::ReasoningDelta
    # Show thinking process if desired
    print "[thinking] #{event.content}"

  when Riffer::StreamEvents::ReasoningDone
    puts "\n[reasoning complete]"

  when Riffer::StreamEvents::Interrupt
    puts "\n[interrupted]"
  end
end
```

## Base Class

All events inherit from `Riffer::StreamEvents::Base`:

```ruby
class Riffer::StreamEvents::Base
  attr_reader :role

  def initialize(role: "assistant")
    @role = role
  end

  def to_h
    raise NotImplementedError
  end
end
```
