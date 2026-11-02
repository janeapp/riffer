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
file = Riffer::Messages::User::FilePart.from_path("photo.jpg")
msg = Riffer::Messages::User.new("Describe this image", files: [file])
msg.files    # => [#<Riffer::Messages::User::FilePart ...>]
msg.to_h     # => {role: :user, content: "Describe this image", files: [{...}]}
```

### Assistant

Assistant messages represent LLM responses, potentially including tool calls, token usage data, and the reason the model finished:

```ruby
# Text-only response
msg = Riffer::Messages::Assistant.new("I'm doing well, thank you!")
msg.role           # => :assistant
msg.content        # => "I'm doing well, thank you!"
msg.tool_calls     # => []
msg.token_usage    # => nil or Riffer::Providers::TokenUsage
msg.finish_reason      # => nil or a normalized Symbol (see below)
msg.finish_reason_raw  # => nil or the provider's raw wire value (e.g. "max_tokens")

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

#### Tool Calls

`Riffer::Messages::Assistant::ToolCall` is the normalized container riffer stores a requested tool invocation in. Each call carries `call_id` (the provider's identifier, passed back as the tool result's `tool_call_id`), `name`, and `arguments` (the JSON-encoded argument string exactly as the provider emitted it); `to_h` serializes all three.

```ruby
tool_call = Riffer::Messages::Assistant::ToolCall.new(call_id: "call_123", name: "weather_tool", arguments: '{"city":"Tokyo"}')
msg = Riffer::Messages::Assistant.new("", tool_calls: [tool_call])

msg.has_tool_calls?        # => true
msg.tool_calls.first.name  # => "weather_tool"
tool_call.to_h             # => {call_id: "call_123", name: "weather_tool", arguments: '{"city":"Tokyo"}'}
```

#### Token Usage Semantics

`TokenUsage` buckets carry the same meaning for every provider, regardless of how the provider reports its raw usage:

- `input_tokens` — every token entering the context window, including cache reads and writes.
- `output_tokens` — every token the model generated, including reasoning/thinking tokens.
- `cache_read_tokens` — the subset of `input_tokens` read from the provider's prompt cache; `nil` when the provider doesn't report it.
- `cache_write_tokens` — the subset of `input_tokens` written to the provider's prompt cache; `nil` when the provider doesn't report it.

The cache buckets are subsets of `input_tokens`, never additions to it — summing `input_tokens + cache_read_tokens` double-counts. `total_tokens` (input + output) matches the totals providers report on their dashboards.

- `cost` — the computed cost of the call, set when a [catalog](CATALOG.md#pricing) or the deprecated [`config.pricing`](CONFIGURATION.md#pricing-deprecated) prices the model in use; `nil` when the model is unpriced. It's for observability, not billing. Run-level usage sums per-call costs through `TokenUsage#+`, so `response.token_usage.cost` is the total spend across the run — but the sum is `nil` if any call in the run used an unpriced model, rather than silently under-reporting.

#### Finish Reasons

`finish_reason` carries the same meaning for every provider — each adapter maps its raw wire value (Anthropic's `end_turn`, OpenAI's response status, Gemini's `STOP`, …) into a normalized vocabulary:

| Value               | Meaning                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `:stop`             | The model finished its turn naturally (or hit a stop sequence).                                                              |
| `:length`           | Output was truncated at the max-token limit.                                                                                 |
| `:tool_calls`       | The model stopped to call tools.                                                                                             |
| `:content_filter`   | A provider safety system blocked or cut the response.                                                                        |
| `:context_window`   | Input plus output hit the model's context window; trim or compact history rather than raising `max_tokens`.                  |
| `:malformed_output` | The model emitted output the provider could not parse, such as an invalid tool call; retry or nudge rather than backing off. |
| `:error`            | The provider reported an error finish.                                                                                       |
| `:other`            | A provider-specific value with no normalized equivalent.                                                                     |

`finish_reason` is `nil` when the provider doesn't report one. The provider's raw wire value travels alongside as `finish_reason_raw` on the message (round-tripped through `to_h` / `from_hash`), on the `FinishReasonDone` stream event, and as the `riffer.finish_reason.raw` trace attribute — for OpenRouter that is the upstream model's `native_finish_reason`, and for a failed OpenAI response it is the error code. Use `finish_reason` to detect truncation without parsing provider responses:

```ruby
response = agent.generate("Summarize this document")
retry_with_higher_limit if agent.session.messages.last.finish_reason == :length
```

#### Structured Output on Messages

When an agent has `structured_output` configured, the final assistant message stores the parsed hash directly. The message holds the parsed JSON, not the schema-validated result; schema validation is reported on `response.outcome` (see [Agent Lifecycle — response.outcome](AGENT_LIFECYCLE.md#responseoutcome)). The `structured_output?` predicate checks for a non-nil value:

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

#### Reasoning

Reasoning models emit thinking blocks alongside their answer, and several providers require those blocks back on the next turn of a tool-calling loop. `Riffer::Messages::Assistant::ReasoningPart` is the normalized container riffer stores them in: a list of parts on the assistant message, in the order the provider emitted them.

```ruby
summary = Riffer::Messages::Assistant::ReasoningPart.new(type: :summary, text: "The user wants the answer.", format: "mock-v1")
opaque = Riffer::Messages::Assistant::ReasoningPart.new(type: :encrypted, data: "b3BhcXVl", format: "mock-v1")
msg = Riffer::Messages::Assistant.new("42", reasoning: [summary, opaque])

msg.reasoning?            # => true
msg.reasoning_text        # => "The user wants the answer."
msg.reasoning.first.type  # => :summary
```

A readable part next to an opaque one is the common shape, not a contrived one: OpenAI's Responses API returns a reasoning item as summary text plus an encrypted payload, and Anthropic pairs a `thinking` block with a `redacted_thinking` block when it redacts part of the chain of thought.

`reasoning:` takes `ReasoningPart`s; `Riffer::Messages::Base.from_hash` is what turns persisted hashes back into parts.

Each part carries:

| Field       | Type      | Description                                                                                                     |
| ----------- | --------- | --------------------------------------------------------------------------------------------------------------- |
| `type`      | `Symbol`  | One of `:text` (readable reasoning), `:summary` (a provider-condensed digest), `:encrypted` (an opaque payload) |
| `text`      | `String?` | The reasoning prose, for `:text` and `:summary` parts                                                           |
| `data`      | `String?` | The opaque payload, for `:encrypted` parts                                                                      |
| `signature` | `String?` | The provider's signature over the part, when it issues one                                                      |
| `id`        | `String?` | The provider's identifier for the part, when it issues one                                                      |
| `format`    | `String?` | The wire format, owned by the adapter that produced the part (e.g. `"anthropic-messages-v1"`)                   |

A `type` outside the three values raises `Riffer::ArgumentError`. `format` is a free string riffer never validates — it exists so an adapter can tell its own parts apart from another adapter's.

`reasoning?` is true when the message carries any part. `reasoning_text` joins the `text` of the `:text` and `:summary` parts with blank lines, skipping `:encrypted` parts, and is `nil` when there is nothing to join. The run's final assistant message projects its parts onto `response.reasoning` (see [Agent Lifecycle — Response Attributes](AGENT_LIFECYCLE.md#response-attributes)).

Parts round-trip through `to_h` / `from_hash` like every other message field, so an application that persists sessions can store and replay them. The `reasoning` key is absent from `to_h` when the message has no parts, and each part omits the fields it doesn't carry:

```ruby
msg.to_h
# => {role: :assistant, content: "42", reasoning: [
#      {type: :summary, text: "The user wants the answer.", format: "mock-v1"},
#      {type: :encrypted, data: "b3BhcXVl", format: "mock-v1"}
#    ]}

Riffer::Messages::Base.from_hash(msg.to_h).reasoning  # => [ReasoningPart, ReasoningPart]
```

**The replay contract.** A provider adapter replays only the parts whose `format` it recognizes and silently skips the rest, so history that travelled through another provider is never rejected. A part with no `format` is never replayed; adapters that surface reasoning text but cannot yet send it back emit their parts that way, so the text is kept for display without risking a rejected request. Parts are never reordered, merged, or edited — riffer treats them as opaque, because the provider's signature covers their exact bytes.

An application that would rather not store reasoning can leave it out when it serializes. When the hash also carries [`parts`](#parts), drop the reasoning entries there too, or `from_hash` reads them back:

```ruby
hash = msg.to_h.except(:reasoning)
hash[:parts] = hash[:parts].reject { |part| part[:part] == :reasoning } if hash[:parts]
```

To drop parts from the in-memory session mid-run instead, `Session#update(id:, reasoning: [])` rewrites the message in place; it needs [message ids](#ids) enabled to address it.

#### Parts

`parts` is the assistant turn in the order the provider produced it. `content`, `tool_calls` and `reasoning` are views over it. Some providers interleave reasoning, server-side tools and text in one turn, and Anthropic needs the turn back in that order: Claude signs each thinking block over every block before it. Sending earlier turns back unchanged also keeps the model's own reasoning and search results, and keeps the prompt cache warm, since the history doesn't change between requests.

A part is one of:

| Class            | Holds                                                                                                                                  |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `TextPart`       | One stretch of answer text (`text`). `data` keeps the provider's block when it carries more than the text, such as Anthropic citations |
| `ReasoningPart`  | A thinking block (see [Reasoning](#reasoning))                                                                                         |
| `ToolCall`       | A function call riffer runs (see [Tool Calls](#tool-calls))                                                                            |
| `ServerToolPart` | A call (`kind: :call`) or result (`kind: :result`) of a tool the provider ran itself, such as web search                               |

```ruby
msg = Riffer::Messages::Assistant.new(parts: [
  Riffer::Messages::Assistant::TextPart.new("Let me check. "),
  Riffer::Messages::Assistant::ServerToolPart.new(name: "web_search", kind: :call, id: "srvtoolu_1", data: "{...}", format: "anthropic-messages-v1"),
  Riffer::Messages::Assistant::ServerToolPart.new(name: "web_search", kind: :result, id: "srvtoolu_1", data: "{...}", format: "anthropic-messages-v1"),
  Riffer::Messages::Assistant::ReasoningPart.new(type: :text, text: "", signature: "CAQS...", format: "anthropic-messages-v1"),
  Riffer::Messages::Assistant::TextPart.new("The latest stable Ruby version is 4.0.9.")
])

msg.content     # => "Let me check. The latest stable Ruby version is 4.0.9."
msg.reasoning   # => [ReasoningPart]
msg.reasoning?  # => true; server tool parts don't count as reasoning
```

- `content` joins the text parts with no separator.
- `Assistant.new(content, tool_calls:, reasoning:)` builds the parts in a fixed order: reasoning, then `content` as one text part (none when empty), then tool calls.
- Passing `parts:` together with `content`, `tool_calls:` or `reasoning:` raises `Riffer::ArgumentError`.
- `ServerToolPart#data` holds the provider's block as JSON, unchanged. It follows the same replay contract as reasoning: only the adapter that recognizes its `format` sends it back, and other adapters skip it. The same goes for a `TextPart` that carries `data`; other adapters send its `text`.

`to_h` keeps the `content`, `tool_calls` and `reasoning` keys. It adds a `parts` key only when those three can't rebuild the parts: a server tool part, a text part with `data`, or parts out of the fixed order. Each entry is the part's own hash plus a `part` tag (`:text`, `:reasoning`, `:tool_call` or `:server_tool`). `from_hash` reads `parts` when present and the old keys otherwise, so earlier persisted messages load unchanged.

```ruby
msg.to_h[:parts]
# => [{part: :text, text: "Let me check. "},
#     {part: :server_tool, name: "web_search", kind: :call, data: "{...}", id: "srvtoolu_1", format: "anthropic-messages-v1"},
#     ...]
```

If you persist sessions, keep the `parts` key. Without it the turn falls back to the fixed order and loses its server tool parts, so Anthropic may reject a later turn or search again.

**Editing a turn.** Riffer sends the parts back as they are. When you change a turn's text (in an output guardrail, or with `Session#update`), keeping the rest of the turn consistent is up to you:

- Drop that turn's reasoning parts. They were signed over the old text, so Anthropic would reject them or drop them silently, and they may still hold the text you removed.
- Keep server tool parts and tool calls, so the model doesn't search again and tool results keep their call.
- Put the new text after the last server tool part and before the first tool call.

```ruby
def redact(message, text)
  kept = message.parts.reject do |part|
    part.is_a?(Riffer::Messages::Assistant::ReasoningPart) || part.is_a?(Riffer::Messages::Assistant::TextPart)
  end
  index = kept.index { |part| part.is_a?(Riffer::Messages::Assistant::ToolCall) } || kept.length
  parts = kept.insert(index, Riffer::Messages::Assistant::TextPart.new(text))

  Riffer::Messages::Assistant.new(
    parts: parts,
    id: message.id,
    token_usage: message.token_usage,
    finish_reason: message.finish_reason,
    finish_reason_raw: message.finish_reason_raw
  )
end
```

`Assistant.new(text)` and `Session#update(id:, content:)` don't follow these rules. They rebuild the turn in the fixed order, which keeps the reasoning and drops server tool parts. Use `Session#update(id:, parts:)` to replace the parts as given.

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

`Riffer::Messages::User::FilePart` represents a file attachment (image or document) that can be included with user messages.

### Supported Media Types

**Images**: `image/jpeg`, `image/png`, `image/gif`, `image/webp`

**Documents**: `application/pdf`, `text/plain`, `text/csv`, `text/html`

### Creating File Parts

```ruby
# From a file path (reads eagerly, detects media type from extension)
file = Riffer::Messages::User::FilePart.from_path("photo.jpg")
file.media_type  # => "image/jpeg"
file.filename    # => "photo.jpg"
file.image?      # => true

# From a URL (stored directly, resolved lazily if provider needs bytes)
file = Riffer::Messages::User::FilePart.from_url("https://example.com/doc.pdf")
file.url?        # => true
file.document?   # => true

# From raw base64 data
file = Riffer::Messages::User::FilePart.new(media_type: "image/png", data: base64_string, filename: "chart.png")

# With an expected sha256 checksum of the file's contents
file = Riffer::Messages::User::FilePart.from_url(
  "https://example.com/doc.pdf",
  sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
)
file.sha256  # => "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
```

`sha256:` accepts a 64-character hex digest (case-insensitive; normalized to lowercase). Raises `Riffer::ArgumentError` on any other format.

### Hash Shorthand

When passing files to agents or messages, hashes are automatically converted:

```ruby
# Path shorthand
{path: "photo.jpg"}

# URL shorthand (media_type auto-detected from extension, or provide explicitly)
{url: "https://example.com/photo.jpg"}
{url: "https://example.com/file", media_type: "application/pdf"}
{url: "https://example.com/file", media_type: "application/pdf", sha256: "e3b0c4..."}

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

For multi-turn conversations restored from persisted state, construct a `Riffer::Agent::Session` with the message history and hand it to a new agent:

```ruby
session = Riffer::Agent::Session.new(messages: [
  Riffer::Messages::User.new("What's the weather?"),
  Riffer::Messages::Assistant.new("I'll check that for you."),
  Riffer::Messages::User.new("Thanks, I meant in Tokyo specifically.")
])

agent = MyAgent.new(session: session)
response = agent.generate   # session already carries the last user turn
```

`Riffer::Agent::Session.new(messages:)` accepts `Riffer::Messages::Base` objects. If your persistence layer hands back hashes, normalize them first via `Riffer::Messages::Base.from_hash` (which dispatches on `:role`), a role's own `from_hash` such as `Riffer::Messages::User.from_hash` when the role is already known, or your own adapter.

### Accessing Message History

Conversation state lives on `agent.session` — a `Riffer::Agent::Session` instance. After calling `generate` or `stream`, access the full conversation:

```ruby
agent = MyAgent.new
agent.generate("Hello!")

agent.session.messages.each do |msg|
  puts "[#{msg.role}] #{msg.content}"
end
# [system] You are a helpful assistant.
# [user] Hello!
# [assistant] Hi there! How can I help you today?
```

`Riffer::Agent::Session` includes `Enumerable`, so `find`, `select`, `count`, `reverse_each` etc. work directly on the session without going through `.messages`.

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

See [Agent Lifecycle - on_message](AGENT_LIFECYCLE.md#on_message) for details.

## Consecutive Message Merging

Before messages reach a provider adapter, Riffer merges consecutive messages that share the same role into a single message. This guarantees every provider receives an identical message list, regardless of how it handles consecutive same-role messages internally.

Without this step, the same model can receive different input depending on the provider. Anthropic's API silently merges consecutive user messages server-side, while Bedrock and Gemini reject them outright. Normalizing at the Riffer level removes that divergence.

### Merge rules

| Message type | Content              | Auxiliary data                                   | Merged?                                  |
| ------------ | -------------------- | ------------------------------------------------ | ---------------------------------------- |
| `System`     | Joined with `"\n\n"` | —                                                | Yes                                      |
| `User`       | Joined with `"\n\n"` | `files` arrays concatenated                      | Yes                                      |
| `Assistant`  | Joined with `"\n\n"` | `tool_calls` and `reasoning` arrays concatenated | Yes                                      |
| `Tool`       | —                    | —                                                | Never (each has a unique `tool_call_id`) |

When either assistant message has [parts](#parts) its fields can't rebuild, the merged message concatenates the two `parts` lists instead, with a `"\n\n"` text part between the texts.

### Example

When a context message is injected before the user's turn, two consecutive user messages are merged into one:

```ruby
session = Riffer::Agent::Session.new(messages: [
  Riffer::Messages::System.new("You are a code reviewer."),
  Riffer::Messages::User.new("The repository uses RSpec for testing."),
  Riffer::Messages::User.new("Review this pull request.")
])

MyAgent.new(session: session).generate
# The provider receives two messages:
#   1. System  — "You are a code reviewer."
#   2. User    — "The repository uses RSpec for testing.\n\nReview this pull request."
```

Merging happens at serialization time only. The session's `messages` array still contains the original separate messages for logging, evals, and debugging.

## IDs

Every message carries an optional `id` attribute. By default ids are disabled (`message.id` returns `nil` and `:id` is omitted from `to_h`). Enable them globally by setting `Riffer.config.message_id_strategy`:

```ruby
Riffer.configure { |c| c.message_id_strategy = :uuidv7 }

msg = Riffer::Messages::User.new("Hello")
msg.id     # => "0195a2e1-..." (auto-generated UUIDv7)
msg.to_h   # => {role: :user, content: "Hello", id: "0195a2e1-..."}
```

Supported strategies: `:none` (default), `:uuid`, `:uuidv7`. See [Configuration — Message ID Strategy](CONFIGURATION.md#message-id-strategy) for the full reference.

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

## Editing history after the fact

The session's `messages` array is mutable, but the message value objects themselves are immutable. To edit recorded history — truncate an assistant message, rewrite a tool result, fill an orphan `tool_use` — use the mutators on `agent.session` (`update`, `remove`). Each one enforces the `tool_use` ↔ `tool_result` invariant. See [Mutating history](AGENT_LIFECYCLE.md#mutating-history) for the full list.
