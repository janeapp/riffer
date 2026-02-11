# Guardrails

Guardrails provide pre-processing of input messages (before LLM calls) and post-processing of output responses (after LLM responses). They enable validation, transformation, and content filtering in the agent pipeline.

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

## Configuration Methods

### identifier

Sets a custom identifier (defaults to snake_case class name):

```ruby
class MyGuardrail < Riffer::Guardrail
  identifier "my_custom_guardrail"
end

MyGuardrail.identifier  # => "my_custom_guardrail"
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
  guardrail :around, with: Riffer::Guardrails::MaxLength, max: 1000
end
```

### Phases

- `:before` - Runs before the LLM call on input messages
- `:after` - Runs after the LLM call on the response
- `:around` - Runs on both before and after

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
response.blocked?       # true if a guardrail blocked execution
response.tripwire       # Tripwire object with block details (if blocked)
response.modified?      # true if any guardrail transformed data
response.modifications  # Array of Modification records
```

### Handling Blocked Responses

```ruby
response = MyAgent.generate("Hello")

if response.blocked?
  puts "Blocked: #{response.tripwire.reason}"
  puts "Phase: #{response.tripwire.phase}"
  puts "Guardrail: #{response.tripwire.guardrail_id}"
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
    puts "Guardrail: #{mod.guardrail_id}"
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
    puts "Modified by: #{event.guardrail_id} (#{event.phase})"
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

## Built-in Guardrails

### MaxLength

Blocks messages or responses that exceed a maximum character length:

```ruby
class MyAgent < Riffer::Agent
  model "anthropic/claude-haiku-4-5-20251001"

  # Block input messages over 1000 characters
  guardrail :before, with: Riffer::Guardrails::MaxLength, max: 1000

  # Block responses over 5000 characters
  guardrail :after, with: Riffer::Guardrails::MaxLength, max: 5000

  # Apply to both with default limit (10,000 characters)
  guardrail :around, with: Riffer::Guardrails::MaxLength
end
```

## Custom Guardrail Examples

### Unicode Normalizer

```ruby
class UnicodeNormalizer < Riffer::Guardrail
  identifier "unicode_normalizer"

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
  identifier "token_limiter"

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

### Content Policy Filter

```ruby
class ContentPolicyFilter < Riffer::Guardrail
  identifier "content_policy"

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

## Error Handling

Exceptions raised in guardrails propagate directly to the caller. Handle them as you would any other exception:

```ruby
begin
  response = MyAgent.generate("Hello")
rescue => e
  puts "Error: #{e.message}"
end
```
