# Adding a New Provider

## Steps

1. Create `lib/riffer/providers/your_provider.rb` extending `Riffer::Providers::Base`
2. Implement the required hook methods (see below)
3. Register in `Riffer::Providers::Repository::REPO`
4. Add provider config to `Riffer::Config` if needed
5. Create tests in `test/riffer/providers/your_provider_test.rb`

## Architecture

The base class uses the **template method** pattern. The public methods `generate_text` and `stream_text` orchestrate the flow, delegating to hook methods that each provider implements:

```
generate_text
  ├─ build_request_params
  ├─ execute_generate
  ├─ extract_content
  ├─ extract_tool_calls
  └─ extract_token_usage

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
  # If supporting web search, extract `web_search` from options and convert
  # it to a provider-native tool format (e.g., OpenAI's `web_search_preview`
  # or Anthropic's `web_search_20250305` server tool).
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

  # Extract text content from the SDK response.
  #
  #: (untyped) -> String
  def extract_content(response)
    # Return the text content from the response
  end

  # Extract tool calls from the SDK response.
  #
  #: (untyped) -> Array[Riffer::Messages::Assistant::ToolCall]
  def extract_tool_calls(response)
    # Return an array of ToolCall structs
  end
end
```

## Structured Output

When structured output is configured, the agent passes a `Riffer::StructuredOutput` instance via `options[:structured_output]`. Providers must extract it from options (and exclude it from the splat) and convert it to their SDK-specific format.

### Extracting from options

All providers follow the same pattern:

```ruby
def build_request_params(messages, model, options)
  structured_output = options[:structured_output]

  params = {
    # ...
    **options.except(:tools, :structured_output)
  }

  # Convert to provider-specific format (see below)
end
```

### Strict schema

All providers apply `strict_schema` (defined in `Providers::Base`) to schemas sent to LLMs — both structured output and tool parameters. This transformation:

- Moves all properties into `required`
- Makes originally-optional properties nullable (`[type, "null"]`)
- Recurses into nested objects and array items

This ensures all providers return proper `null` for optional fields instead of empty strings or garbage.

### Provider-specific formats

**OpenAI** — uses `params[:text][:format]` with `strict: true`:

```ruby
if structured_output
  params[:text] = {
    format: {
      type: "json_schema",
      name: "response",
      schema: strict_schema(structured_output.json_schema),
      strict: true
    }
  }
end
```

**Anthropic** — uses `params[:output_config]`:

```ruby
if structured_output
  params[:output_config] = {
    format: {
      type: "json_schema",
      schema: strict_schema(structured_output.json_schema)
    }
  }
end
```

**Amazon Bedrock** — uses `params[:output_config][:text_format]` with stringified schema:

```ruby
if structured_output
  params[:output_config] = {
    text_format: {
      type: "json_schema",
      structure: {
        json_schema: {
          schema: strict_schema(structured_output.json_schema).to_json,
          name: "response"
        }
      }
    }
  }
end
```

### Key details

- `structured_output.json_schema` returns a Hash with `type`, `properties`, `required`, and `additionalProperties` keys
- All providers wrap schemas with `strict_schema` to ensure proper null handling
- Bedrock requires the schema as a JSON string (`.to_json`), others use the Hash directly
- The agent handles parsing and validation of the response — providers only need to pass the schema to the SDK

## File Handling

User messages may include `Riffer::FilePart` objects in their `files` array. Each provider's `build_request_params` (or its message conversion helpers) must convert these to provider-specific content blocks:

- **OpenAI**: `input_image` (URLs or data URIs) and `input_file` (data URIs)
- **Anthropic**: `image` and `document` blocks with `url` or `base64` source
- **Bedrock**: `image` and `document` blocks with `bytes` source (always base64, URLs are resolved)

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
