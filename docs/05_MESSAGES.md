# Messages

Messages represent the conversation between users and the assistant. Riffer uses strongly-typed message objects to ensure consistency and type safety.

## Message Types

### System

System messages provide instructions to the LLM:

```ruby
msg = Riffer::Messages::System.new("You are a helpful assistant.")
msg.role     # => :system
msg.content  # => "You are a helpful assistant."
msg.to_h     # => {role: :system, content: "You are a helpful assistant."}
```

System messages are typically set via agent `instructions` and automatically prepended to conversations.

### User

User messages represent input from the user:

```ruby
msg = Riffer::Messages::User.new("Hello, how are you?")
msg.role     # => :user
msg.content  # => "Hello, how are you?"
msg.files    # => []
msg.to_h     # => {role: :user, content: "Hello, how are you?"}
```

User messages can include file attachments:

```ruby
file = Riffer::FilePart.from_path("photo.jpg")
msg = Riffer::Messages::User.new("Describe this image", files: [file])
msg.files    # => [#<Riffer::FilePart ...>]
msg.to_h     # => {role: :user, content: "Describe this image", files: [{...}]}
```

### Assistant

Assistant messages represent LLM responses, potentially including tool calls and token usage data:

```ruby
# Text-only response
msg = Riffer::Messages::Assistant.new("I'm doing well, thank you!")
msg.role         # => :assistant
msg.content      # => "I'm doing well, thank you!"
msg.tool_calls   # => []
msg.token_usage  # => nil or Riffer::TokenUsage

# Response with tool calls
msg = Riffer::Messages::Assistant.new("", tool_calls: [
  {id: "call_123", call_id: "call_123", name: "weather_tool", arguments: '{"city":"Tokyo"}'}
])
msg.tool_calls  # => [{id: "call_123", ...}]
msg.to_h        # => {role: "assistant", content: "", tool_calls: [...]}

# Accessing token usage data (when available from provider)
if msg.token_usage
  puts "Input tokens: #{msg.token_usage.input_tokens}"
  puts "Output tokens: #{msg.token_usage.output_tokens}"
  puts "Total tokens: #{msg.token_usage.total_tokens}"
end
```

### Tool

Tool messages contain the results of tool executions:

```ruby
msg = Riffer::Messages::Tool.new(
  "The weather in Tokyo is 22C and sunny.",
  tool_call_id: "call_123",
  name: "weather_tool"
)
msg.role          # => :tool
msg.content       # => "The weather in Tokyo is 22C and sunny."
msg.tool_call_id  # => "call_123"
msg.name          # => "weather_tool"
msg.error?        # => false

# Error result
msg = Riffer::Messages::Tool.new(
  "API rate limit exceeded",
  tool_call_id: "call_123",
  name: "weather_tool",
  error: "API rate limit exceeded",
  error_type: :execution_error
)
msg.error?      # => true
msg.error       # => "API rate limit exceeded"
msg.error_type  # => :execution_error
```

## File Parts

`Riffer::FilePart` represents a file attachment (image or document) that can be included with user messages.

### Supported Media Types

**Images**: `image/jpeg`, `image/png`, `image/gif`, `image/webp`

**Documents**: `application/pdf`, `text/plain`, `text/csv`, `text/html`

### Creating File Parts

```ruby
# From a file path (reads eagerly, detects media type from extension)
file = Riffer::FilePart.from_path("photo.jpg")
file.media_type  # => "image/jpeg"
file.filename    # => "photo.jpg"
file.image?      # => true

# From a URL (stored directly, resolved lazily if provider needs bytes)
file = Riffer::FilePart.from_url("https://example.com/doc.pdf")
file.url?        # => true
file.document?   # => true

# From raw base64 data
file = Riffer::FilePart.new(media_type: "image/png", data: base64_string, filename: "chart.png")
```

### Hash Shorthand

When passing files to agents or messages, hashes are automatically converted:

```ruby
# Path shorthand
{path: "photo.jpg"}

# URL shorthand (media_type auto-detected from extension, or provide explicitly)
{url: "https://example.com/photo.jpg"}
{url: "https://example.com/file", media_type: "application/pdf"}

# Data shorthand
{data: base64_string, media_type: "image/png", filename: "chart.png"}
```

### Predicates

```ruby
file.image?     # true for image/* media types
file.document?  # true for non-image media types
file.url?       # true when source was a URL
```

## Using Messages with Agents

### String Prompts

The simplest way to interact with an agent:

```ruby
agent = MyAgent.new
response = agent.generate("Hello!")
```

This creates a `User` message internally.

### Message Arrays

For multi-turn conversations, pass an array of messages:

```ruby
messages = [
  {role: :user, content: "What's the weather?"},
  {role: :assistant, content: "I'll check that for you."},
  {role: :user, content: "Thanks, I meant in Tokyo specifically."}
]

response = agent.generate(messages)
```

Messages can be hashes or `Riffer::Messages::Base` objects:

```ruby
messages = [
  Riffer::Messages::User.new("Hello"),
  Riffer::Messages::Assistant.new("Hi there!"),
  Riffer::Messages::User.new("How are you?")
]

response = agent.generate(messages)
```

### Accessing Message History

After calling `generate` or `stream`, access the full conversation:

```ruby
agent = MyAgent.new
agent.generate("Hello!")

agent.messages.each do |msg|
  puts "[#{msg.role}] #{msg.content}"
end
# [system] You are a helpful assistant.
# [user] Hello!
# [assistant] Hi there! How can I help you today?
```

## Tool Call Structure

Tool calls in assistant messages have this structure:

```ruby
{
  id: "item_123",       # Item identifier
  call_id: "call_456",  # Call identifier for response matching
  name: "weather_tool", # Tool name
  arguments: '{"city":"Tokyo"}'  # JSON string of arguments
}
```

When creating tool result messages, use the `id` as `tool_call_id`.

## Message Emission

Agents can emit messages as they're added during generation via the `on_message` callback. This is useful for persistence or real-time logging. Only agent-generated messages (Assistant, Tool) are emitted—not inputs (System, User).

See [Agents - on_message](03_AGENTS.md#on_message) for details.

## Base Class

All messages inherit from `Riffer::Messages::Base`:

```ruby
class Riffer::Messages::Base
  attr_reader :content

  def role
    raise NotImplementedError
  end

  def to_h
    {role: role, content: content}
  end
end
```

Subclasses implement `role` and optionally extend `to_h` with additional fields.
