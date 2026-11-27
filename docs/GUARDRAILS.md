# Guardrails

Guardrails provide pre-processing of input messages (before LLM calls) and post-processing of output responses (after LLM responses). They enable validation, transformation, and content filtering in the agent pipeline.

## When to Use Guardrails

Use guardrails when you need to enforce rules that apply to every request — content filtering, PII redaction, length limits, or input validation. If you need one-off conditional logic, handle it in your tool or agent instructions instead.

## Quickstart

```ruby
require 'riffer'

class ProfanityFilter < Riffer::Guardrail
  def process_input(messages, context:)
    if messages.any? { |m| m.content&.match?(/badword/i) }
      block("Profanity detected")
    else
      pass(messages)
    end
  end
end

class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are a helpful assistant.'
  guardrail :before, with: ProfanityFilter
end

response = MyAgent.generate("Hello!")
response.outcome.reason    # => :completed

response = MyAgent.generate("You are a badword")
response.outcome.reason    # => :guardrail_blocked
response.tripwire.reason   # => "Profanity detected"
```

> **Tip:** See [`examples/guardrails/`](https://github.com/janeapp/riffer/tree/main/examples/guardrails) for more ready-to-use reference implementations.

## Overview

Guardrails can:

- **Transform** - Modify messages or responses (e.g., redact PII, normalize text)
- **Pass** - Allow data through unchanged
- **Block** - Halt execution with a reason (e.g., content policy violation)

## Defining a Guardrail

Create a guardrail by subclassing `Riffer::Guardrail`:

```ruby
class ContentFilterGuardrail < Riffer::Guardrail
  def process_input(messages, context:)
    if contains_inappropriate_content?(messages)
      block("Content policy violation detected")
    else
      pass(messages)
    end
  end

  def process_output(response, messages:, context:)
    if contains_inappropriate_content?(response)
      block("Response contains inappropriate content")
    else
      pass(response)
    end
  end

  private

  def contains_inappropriate_content?(data)
    # Your content filtering logic
    false
  end
end
```

## Processing Methods

### process_input

Override to process input messages before they are sent to the LLM:

```ruby
def process_input(messages, context:)
  # messages - Array of Riffer::Messages::Base
  # context - Optional context passed to the agent

  # Return one of:
  pass(messages)           # Continue unchanged
  transform(new_messages)  # Continue with transformed data
  block("reason")          # Halt execution
end
```

### process_output

Override to process the LLM response:

```ruby
def process_output(response, messages:, context:)
  # response - Riffer::Messages::Assistant
  # messages - Array of Riffer::Messages::Base (conversation history)
  # context - Optional context passed to the agent

  # Return one of:
  pass(response)           # Continue unchanged
  transform(new_response)  # Continue with transformed data
  block("reason")          # Halt execution
end
```

### process_downloaded_files

Override to process the messages after the agent downloads their files, before the first LLM call. It runs in the `:after_files_download` phase, which needs `config.future.file_downloads` (see [File Downloads](CONFIGURATION.md#file-downloads)):

```ruby
def process_downloaded_files(messages, context:)
  # messages - Array of Riffer::Messages::Base, with downloaded bytes on their files
  # context - Optional context passed to the agent

  # Return one of:
  pass(messages)           # Continue unchanged
  transform(new_messages)  # Continue with transformed data
  block("reason")          # Halt execution
end
```

Takes and returns the same shape as `process_input`. A transform is recorded as a modification and a block ends the run with `:guardrail_blocked`, as in the other phases. See [Files](#files) for what it sees.

## Result Helpers

Inside guardrail methods, use these helpers to return results:

### pass(data)

Continue with the data unchanged:

```ruby
def process_input(messages, context:)
  pass(messages)
end
```

### transform(data)

Continue with transformed data:

```ruby
def process_input(messages, context:)
  sanitized = messages.map { |m| sanitize_message(m) }
  transform(sanitized)
end
```

### block(reason, metadata: nil)

Halt execution with a reason:

```ruby
def process_input(messages, context:)
  block("Content policy violation", metadata: {type: :profanity})
end
```

## Using Guardrails with Agents

Register guardrails with the `guardrail` DSL method. Pass the guardrail class (not an instance) and any options:

```ruby
class MyAgent < Riffer::Agent
  model "anthropic/claude-haiku-4-5-20251001"
  instructions "You are a helpful assistant."

  # Input-only guardrail
  guardrail :before, with: InputValidator

  # Output-only guardrail
  guardrail :after, with: ResponseFilter

  # Both input and output (around) with options
  guardrail :around, with: MaxLengthGuardrail, max: 1000
end
```

Extra keyword arguments after `with:` are forwarded to the guardrail's `initialize` method. For example, `max: 1000` above is passed as `MaxLengthGuardrail.new(max: 1000)`.

### Phases

- `:before` - Runs before the LLM call on input messages
- `:after` - Runs after the LLM call on the response
- `:around` - Runs on both before and after
- `:after_files_download` - Runs once per run, after the agent downloads files and before the first LLM call. Needs `config.future.file_downloads`; registering it without the flag raises `Riffer::ArgumentError`, so turn the flag on before your agent classes load. `:around` doesn't include it.

### Multiple Guardrails

Guardrails execute sequentially in registration order:

```ruby
class MyAgent < Riffer::Agent
  model "anthropic/claude-haiku-4-5-20251001"

  guardrail :before, with: FirstGuardrail   # Runs first
  guardrail :before, with: SecondGuardrail  # Runs second
end
```

## Response Object

`generate` returns a `Riffer::Agent::Response` object:

```ruby
response = MyAgent.generate("Hello")

response.content        # The response text
response.outcome.reason # :guardrail_blocked if a guardrail blocked execution
response.tripwire       # Tripwire object with block details (if blocked)
response.modified?      # true if any guardrail transformed data
response.modifications  # Array of Modification records
```

### Handling Blocked Responses

```ruby
response = MyAgent.generate("Hello")

if response.outcome.reason == :guardrail_blocked
  puts "Blocked: #{response.tripwire.reason}"
  puts "Phase: #{response.tripwire.phase}"
  puts "Guardrail: #{response.tripwire.guardrail}"
else
  puts response.content
end
```

### Modification Tracking

When guardrails transform data, modification records track which guardrail made changes and which messages were affected:

```ruby
response = MyAgent.generate("Hello")

if response.modified?
  response.modifications.each do |mod|
    puts "Guardrail: #{mod.guardrail}"
    puts "Phase: #{mod.phase}"
    puts "Changed indices: #{mod.message_indices}"
  end
end
```

During streaming, `GuardrailModification` events are emitted when transforms occur:

```ruby
MyAgent.stream("Hello").each do |event|
  case event
  when Riffer::StreamEvents::GuardrailModification
    puts "Modified by: #{event.guardrail} (#{event.phase})"
  when Riffer::StreamEvents::TextDelta
    print event.content
  end
end
```

## Streaming with Guardrails

Guardrails work with streaming. If blocked, a `Riffer::StreamEvents::GuardrailTripwire` event is yielded:

```ruby
MyAgent.stream("Hello").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::GuardrailTripwire
    puts "Blocked: #{event.reason}"
    puts "Phase: #{event.phase}"
  end
end
```

## Custom Guardrail Examples

### Unicode Normalizer

```ruby
class UnicodeNormalizer < Riffer::Guardrail
  def process_input(messages, context:)
    normalized = messages.map do |msg|
      if msg.respond_to?(:content) && msg.content
        rebuild_message(msg, msg.content.unicode_normalize(:nfc))
      else
        msg
      end
    end
    transform(normalized)
  end

  private

  def rebuild_message(msg, content)
    case msg
    when Riffer::Messages::User
      Riffer::Messages::User.new(content)
    when Riffer::Messages::System
      Riffer::Messages::System.new(content)
    else
      msg
    end
  end
end
```

### Token Limiter

```ruby
class TokenLimiter < Riffer::Guardrail
  def initialize(limit:, strategy: :truncate)
    super()
    @limit = limit
    @strategy = strategy
  end

  def process_output(response, messages:, context:)
    content = response.content
    tokens = estimate_tokens(content)

    if tokens > @limit
      case @strategy
      when :truncate
        transform(truncate_response(response))
      when :block
        block("Response exceeds token limit", metadata: {tokens: tokens, limit: @limit})
      else
        pass(response)
      end
    else
      pass(response)
    end
  end

  private

  def estimate_tokens(text)
    text.split.size  # Simplified estimate
  end

  def truncate_response(response)
    words = response.content.split.first(@limit)
    Riffer::Messages::Assistant.new(words.join(" ") + "...")
  end
end
```

`Assistant.new(text)` builds a new turn with only that text, so this example also drops the response's tool calls and server tool parts. When a guardrail changes the text of a response that carries reasoning, server tool parts or tool calls, rebuild its `parts` instead; see [Messages — Editing a turn](MESSAGES.md#parts).

### Content Policy Filter

```ruby
class ContentPolicyFilter < Riffer::Guardrail
  BLOCKED_PATTERNS = [
    /pattern1/i,
    /pattern2/i
  ].freeze

  def process_input(messages, context:)
    messages.each do |msg|
      next unless msg.respond_to?(:content)
      if violates_policy?(msg.content)
        return block("Input violates content policy")
      end
    end
    pass(messages)
  end

  def process_output(response, messages:, context:)
    if violates_policy?(response.content)
      block("Response violates content policy")
    else
      pass(response)
    end
  end

  private

  def violates_policy?(text)
    return false unless text
    BLOCKED_PATTERNS.any? { |pattern| text.match?(pattern) }
  end
end
```

## Files

With `config.future.file_downloads`, riffer checks nothing about files itself, and file policy goes in guardrails (see [File Downloads](CONFIGURATION.md#file-downloads)). Both phases see every file in the messages:

- **`:before`** runs before anything is downloaded. URL policy goes here: host allowlists, file counts, requiring `sha256`, hashing inline bytes, or presigning URLs with `transform`. A host allowlist only checks the first URL, and redirects can lead elsewhere.
- **`:after_files_download`** runs with the downloaded bytes on the files. Content policy goes here: checking `sha256`, checking content against `media_type`, malware scans.

Files the provider sends as URLs are never downloaded, so they have no bytes in `:after_files_download`; tell them apart with `file.data_bytes.nil?`. Nothing downloads a file that an `:after_files_download` transform adds or swaps in: if the provider needs its bytes, it raises `Riffer::FileDataMissingError`. Swap URLs in `:before`.

For example, one guardrail for both phases:

```ruby
class FilePolicy < Riffer::Guardrail
  ALLOWED_HOSTS = ["files.example.com"].freeze

  def process_input(messages, context:)
    files = messages.grep(Riffer::Messages::User).flat_map(&:files)
    return block("too many files") if files.size > 10
    return block("host not allowed") if files.any? { |f| f.url && !ALLOWED_HOSTS.include?(URI(f.url).host) }

    pass(messages)
  end

  def process_downloaded_files(messages, context:)
    files = messages.grep(Riffer::Messages::User).flat_map(&:files)
    bad = files.find { |f| f.sha256 && f.data_bytes && Digest::SHA256.hexdigest(f.data_bytes) != f.sha256 }
    bad ? block("checksum mismatch") : pass(messages)
  end
end

class MyAgent < Riffer::Agent
  model "amazon_bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0"
  guardrail :before, with: FilePolicy
  guardrail :after_files_download, with: FilePolicy
end
```

The checksum check covers inline `data:` or `bytes:` files and downloaded ones alike, since both have `data_bytes` by then.

## Error Handling

Exceptions raised in guardrails propagate directly to the caller. Handle them as you would any other exception:

```ruby
begin
  response = MyAgent.generate("Hello")
rescue => e
  puts "Error: #{e.message}"
end
```
