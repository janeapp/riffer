# Architecture

## Core Components

### Agent (`lib/riffer/agent.rb`)

Base class for AI agents. Subclass and use DSL methods `model` and `instructions` to configure. Orchestrates message flow, LLM calls, and tool execution via a generate/stream loop.

```ruby
class EchoAgent < Riffer::Agent
  model 'openai/gpt-5-mini' # provider/model
  instructions 'You are an assistant that repeats what the user says.'
end

agent = EchoAgent.new
puts agent.generate('Hello world')
```

### Providers (`lib/riffer/providers/`)

Adapters for LLM APIs. The base class uses a template-method pattern — `generate_text` and `stream_text` orchestrate the flow, delegating to five hook methods each provider implements:

- `build_request_params(messages, model, options)` — convert messages, tools, and options into SDK params
- `execute_generate(params)` — call the SDK and return the raw response
- `execute_stream(params, yielder)` — call the streaming SDK, mapping events to the yielder
- `extract_token_usage(response)` — pull token counts from the SDK response
- `extract_assistant_message(response, token_usage)` — parse the SDK response into an `Assistant` message

Providers are registered in `Riffer::Providers::Repository::REPO` with identifiers (e.g., `openai`, `amazon_bedrock`).

### Messages (`lib/riffer/messages/`)

Typed message objects that extend `Riffer::Messages::Base`:

- `System` - system instructions
- `User` - user input
- `Assistant` - AI responses
- `Tool` - tool execution results

The `Converter` module handles hash-to-object conversion.

### StreamEvents (`lib/riffer/stream_events/`)

Structured events for streaming responses:

- `TextDelta` - incremental text chunks
- `TextDone` - completion signals
- `ReasoningDelta` - reasoning process chunks
- `ReasoningDone` - reasoning completion
- `Interrupt` - callback interrupted the agent loop

### Stopping the Loop Early

Two mechanisms can stop the agent loop before the LLM finishes naturally:

**Guardrail tripwires** — declarative policy enforcement registered at class level. A `:before` guardrail can block the request before the LLM is called; an `:after` guardrail can block the response. Tripwires are not resumable — the caller must change the input and start over. `Response#blocked?` returns `true`.

**Callback interrupts** — imperative flow control via `on_message` callbacks. Use `throw :riffer_interrupt` to pause the loop at any point. `Response#interrupted?` returns `true`. In streaming, yields an `Interrupt` event.

### Resuming After an Interrupt

`agent.resume` or `agent.resume_stream` continues an interrupted loop. Both accept `messages:` for cross-process resume from persisted data.

On resume, `execute_pending_tool_calls` detects tool calls from the last assistant message that lack corresponding tool result messages and executes them before entering the LLM loop. This handles the case where an interrupt fired mid-way through tool execution.

## Key Patterns

- Model config accepts a `provider/model` string (e.g., `openai/gpt-4`) or a Proc/lambda that returns one
- Configuration via `Riffer.configure { |c| c.openai.api_key = "..." }`
- Providers use `depends_on` helper for runtime dependency checking
- Zeitwerk for autoloading - file structure must match module/class names

## Project Structure

```
lib/
  riffer.rb              # Main entry point, uses Zeitwerk for autoloading
  riffer/
    version.rb           # VERSION constant
    config.rb            # Configuration class
    core.rb              # Core functionality
    agent.rb             # Agent class
    messages.rb          # Messages namespace/module
    providers.rb         # Providers namespace/module
    stream_events.rb     # Stream events namespace/module
    helpers/
      class_name_converter.rb  # Class name conversion utilities
      dependencies.rb          # Dependency management
      validations.rb           # Validation helpers
    messages/
      base.rb            # Base message class
      assistant.rb       # Assistant message
      converter.rb       # Message converter
      system.rb          # System message
      user.rb            # User message
      tool.rb            # Tool message
    providers/
      base.rb            # Base provider class
      open_ai.rb         # OpenAI provider
      amazon_bedrock.rb  # Amazon Bedrock provider
      repository.rb      # Provider registry
      test.rb            # Test provider
    stream_events/
      base.rb            # Base stream event
      interrupt.rb       # Interrupt event
      text_delta.rb      # Text delta event
      text_done.rb       # Text done event
      reasoning_delta.rb # Reasoning delta event
      reasoning_done.rb  # Reasoning done event
test/
  test_helper.rb         # Minitest configuration with VCR
  riffer_test.rb         # Main module tests
  riffer/
    [feature]_test.rb    # Feature tests mirror lib/riffer/ structure
```

## Configuration Example

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end
```

## Streaming Example

```ruby
agent = EchoAgent.new
agent.stream('Tell me a story').each do |event|
  print event.content
end
```
