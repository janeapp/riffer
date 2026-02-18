# Adding a New Provider

## Steps

1. Create `lib/riffer/providers/your_provider.rb` extending `Riffer::Providers::Base`
2. Implement the required hook methods (see below)
3. Register in `Riffer::Providers::Repository::REPO`
4. Add provider config to `Riffer::Config` if needed
5. Create tests in `test/riffer/providers/your_provider_test.rb`

## Architecture

The base class uses the **template method** pattern. The public methods `generate_text` and `stream_text` orchestrate the flow, delegating to five hook methods that each provider implements:

```
generate_text
  ├─ build_request_params
  ├─ execute_generate
  ├─ extract_token_usage
  └─ extract_assistant_message

stream_text
  ├─ build_request_params
  └─ execute_stream
```

## Required Hook Methods

```ruby
# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Providers::YourProvider < Riffer::Providers::Base
  def initialize(**options)
    depends_on "your-sdk-gem"
    @client = YourSDK::Client.new(**options)
  end

  private

  # Convert messages, tools, and options into SDK-specific params.
  #
  #: (Array[Riffer::Messages::Base], String?, Hash[Symbol, untyped]) -> Hash[Symbol, untyped]
  def build_request_params(messages, model, options)
    # Return a hash that can be passed to both execute_generate and execute_stream
  end

  # Call the SDK and return the raw response object.
  #
  #: (Hash[Symbol, untyped]) -> untyped
  def execute_generate(params)
    @client.create(**params)
  end

  # Call the streaming SDK, mapping provider events to Riffer stream events.
  #
  #: (Hash[Symbol, untyped], Enumerator::Yielder) -> void
  def execute_stream(params, yielder)
    @client.stream(**params) do |event|
      # Map SDK events to Riffer::StreamEvents::* and yield them
      # yielder << Riffer::StreamEvents::TextDelta.new(event.text)
    end
  end

  # Extract token usage from the SDK response.
  #
  #: (untyped) -> Riffer::TokenUsage?
  def extract_token_usage(response)
    usage = response.usage
    return nil unless usage

    Riffer::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens
    )
  end

  # Parse the SDK response into an Assistant message.
  #
  #: (untyped, ?Riffer::TokenUsage?) -> Riffer::Messages::Assistant
  def extract_assistant_message(response, token_usage = nil)
    # Extract text and tool_calls from the response
    Riffer::Messages::Assistant.new(text, tool_calls: tool_calls, token_usage: token_usage)
  end
end
```

## Shared Utilities

The base class provides `parse_tool_arguments` for converting tool call arguments from JSON strings to hashes:

```ruby
# Available in all providers via the base class
parse_tool_arguments('{"key":"value"}')  # => {"key" => "value"}
parse_tool_arguments({"key" => "value"}) # => {"key" => "value"}
parse_tool_arguments(nil)                # => {}
```

## Registration

Add to `Riffer::Providers::Repository::REPO`:

```ruby
REPO = {
  # ... existing providers
  your_provider: -> { YourProvider }
}.freeze
```

## Dependencies

Use `depends_on` helper for runtime dependency checking if your provider requires external gems.
