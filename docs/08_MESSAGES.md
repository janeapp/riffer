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

#### Structured Output on Messages

When an agent has `structured_output` configured, the final assistant message stores the parsed hash directly. The `structured_output?` predicate checks for a non-nil value:

```ruby
msg = Riffer::Messages::Assistant.new('{"sentiment":"positive"}', structured_output: {sentiment: "positive"})
msg.structured_output?    # => true
msg.structured_output     # => {sentiment: "positive"}

# When not provided, structured_output returns nil
msg = Riffer::Messages::Assistant.new('{"sentiment":"positive"}')
msg.structured_output?    # => false
msg.structured_output     # => nil
```

The `to_h` representation includes `structured_output` only when present:

```ruby
msg = Riffer::Messages::Assistant.new('{"sentiment":"positive"}', structured_output: {sentiment: "positive"})
msg.to_h  # => {role: :assistant, content: '{"sentiment":"positive"}', structured_output: {sentiment: "positive"}}
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

See [Agent Lifecycle - on_message](04_AGENT_LIFECYCLE.md#on_message) for details.

## Consecutive Message Merging

Before messages reach a provider adapter, Riffer merges consecutive messages that share the same role into a single message. This guarantees every provider receives an identical message list, regardless of how it handles consecutive same-role messages internally.

Without this step, the same model can receive different input depending on the provider. Anthropic's API silently merges consecutive user messages server-side, while Bedrock and Gemini reject them outright. Normalizing at the Riffer level removes that divergence.

### Merge rules

| Message type | Content              | Auxiliary data                   | Merged?                                  |
| ------------ | -------------------- | -------------------------------- | ---------------------------------------- |
| `System`     | Joined with `"\n\n"` | —                                | Yes                                      |
| `User`       | Joined with `"\n\n"` | `files` arrays concatenated      | Yes                                      |
| `Assistant`  | Joined with `"\n\n"` | `tool_calls` arrays concatenated | Yes                                      |
| `Tool`       | —                    | —                                | Never (each has a unique `tool_call_id`) |

### Example

When a context message is injected before the user's turn, two consecutive user messages are merged into one:

```ruby
messages = [
  Riffer::Messages::System.new("You are a code reviewer."),
  Riffer::Messages::User.new("The repository uses RSpec for testing."),
  Riffer::Messages::User.new("Review this pull request.")
]

agent.generate(messages)
# The provider receives two messages:
#   1. System  — "You are a code reviewer."
#   2. User    — "The repository uses RSpec for testing.\n\nReview this pull request."
```

Merging happens at serialization time only. The agent's `messages` array still contains the original separate messages for logging, evals, and debugging.

## Blank Message Normalization

Some providers (Amazon Bedrock, Anthropic) reject messages whose text content is empty or whitespace-only. Before merging consecutive messages, Riffer replaces blank `User` and `Assistant` messages with a placeholder so that role alternation stays valid on the wire.

The placeholder is exposed as the public constant `Riffer::Messages::Base::BLANK_CONTENT_PLACEHOLDER` (currently `"(no content)"`).

### Normalization rules

| Message     | Trigger                                            | Behavior                                                   |
| ----------- | -------------------------------------------------- | ---------------------------------------------------------- |
| `User`      | `content` is `nil`/blank AND `files` is empty      | Content replaced with `BLANK_CONTENT_PLACEHOLDER`          |
| `User`      | `content` is blank but `files` is non-empty        | Left untouched — file parts satisfy the wire format        |
| `Assistant` | `content` is `nil`/blank AND `tool_calls` is empty | Content replaced with `BLANK_CONTENT_PLACEHOLDER`          |
| `Assistant` | `content` is blank but `tool_calls` is non-empty   | Left untouched — empty text block is stripped per-provider |
| `System`    | —                                                  | Never normalized                                           |
| `Tool`      | —                                                  | Handled at conversion time — see below                     |

For `Tool` messages with blank content, the Bedrock and Anthropic adapters substitute the same placeholder when serializing the `tool_result`, rather than dropping the message — dropping would orphan the matching `tool_use` and trigger a different rejection.

If a placeholder message ends up adjacent to a real-content message of the same role, the placeholder is dropped during [consecutive-message merging](#consecutive-message-merging) — only a fully-blank run survives as a single placeholder.

OpenAI Responses and Gemini accept empty strings and are unaffected in practice, but the normalization runs uniformly for every provider adapter.

## IDs

Every message carries an optional `id` attribute. By default ids are disabled (`message.id` returns `nil` and `:id` is omitted from `to_h`). Enable them globally by setting `Riffer.config.message_id_strategy`:

```ruby
Riffer.configure { |c| c.message_id_strategy = :uuidv7 }

msg = Riffer::Messages::User.new("Hello")
msg.id     # => "0195a2e1-..." (auto-generated UUIDv7)
msg.to_h   # => {role: :user, content: "Hello", id: "0195a2e1-..."}
```

Supported strategies: `:none` (default), `:uuid`, `:uuidv7`. See [Configuration — Message ID Strategy](10_CONFIGURATION.md#message-id-strategy) for the full reference.

Ids pass through to subclass constructors via an `id:` kwarg and are preserved when set explicitly:

```ruby
msg = Riffer::Messages::Assistant.new("Done.", id: "reply-42")
msg.id  # => "reply-42"
```

When seeding an agent with existing conversation history and the strategy is enabled, every seeded message must include an id — Riffer raises `Riffer::ArgumentError` on missing ids rather than fabricating them.

## Base Class

All messages inherit from `Riffer::Messages::Base`:

```ruby
class Riffer::Messages::Base
  attr_reader :content, :id

  def initialize(content, id: nil)
    @content = content
    @id = id || generate_id  # uses Riffer.config.message_id_strategy
  end

  def role
    raise NotImplementedError
  end

  def to_h
    hash = {role: role, content: content}
    hash[:id] = id unless id.nil?
    hash
  end
end
```

Subclasses implement `role` and optionally extend `to_h` with additional fields.
