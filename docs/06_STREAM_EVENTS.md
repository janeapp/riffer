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
