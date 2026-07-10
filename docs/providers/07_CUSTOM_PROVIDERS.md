# Creating Custom Providers

You can create custom providers to connect Riffer to other LLM services.

## Basic Structure

Extend `Riffer::Providers::Base` and implement the five required hook methods:

```ruby
class Riffer::Providers::MyProvider < Riffer::Providers::Base
  def initialize(**options)
    # Initialize your client
    @api_key = options[:api_key] || ENV['MY_PROVIDER_API_KEY']
    @client = MyProviderClient.new(api_key: @api_key)
  end

  private

  # Hook methods (matching base.rb order)

  def build_request_params(messages, model, options)
    tools = options[:tools]

    params = {
      model: model,
      messages: convert_messages(messages),
      **options.except(:tools)
    }

    if tools && !tools.empty?
      params[:tools] = tools.map { |t| convert_tool(t) }
    end

    params
  end

  def execute_generate(params)
    @client.generate(**params)
  end

  def execute_stream(params, yielder)
    @client.stream(**params) do |chunk|
      case chunk.type
      when :text
        yielder << Riffer::StreamEvents::TextDelta.new(chunk.content)
      when :text_done
        yielder << Riffer::StreamEvents::TextDone.new(chunk.content)
      when :tool_call
        yielder << Riffer::StreamEvents::ToolCallDone.new(
          item_id: chunk.id,
          call_id: chunk.id,
          name: chunk.name,
          arguments: chunk.arguments
        )
      end
    end
  end

  def extract_token_usage(response)
    usage = response.usage
    return nil unless usage

    Riffer::Providers::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens
    )
  end

  def extract_assistant_message(response, token_usage = nil)
    text = response.text
    tool_calls = extract_tool_calls(response)

    Riffer::Messages::Assistant.new(
      text,
      tool_calls: tool_calls,
      token_usage: token_usage
    )
  end

  # Helper methods (provider-specific)

  def convert_messages(messages)
    messages.map do |msg|
      case msg
      when Riffer::Messages::System
        {role: "system", content: msg.content}
      when Riffer::Messages::User
        {role: "user", content: msg.content}
      when Riffer::Messages::Assistant
        convert_assistant(msg)
      when Riffer::Messages::Tool
        {role: "tool", tool_call_id: msg.tool_call_id, content: msg.content}
      end
    end
  end

  def convert_assistant(msg)
    {role: "assistant", content: msg.content, tool_calls: msg.tool_calls}
  end

  def convert_tool(tool)
    {
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters_schema
    }
  end

  def extract_tool_calls(response)
    return [] unless response.tool_calls

    response.tool_calls.map do |tc|
      Riffer::Messages::Assistant::ToolCall.new(
        id: tc.id,
        call_id: tc.id,
        name: tc.name,
        arguments: tc.arguments
      )
    end
  end
end
```

## Using depends_on

For lazy loading of external gems:

```ruby
class Riffer::Providers::MyProvider < Riffer::Providers::Base
  def initialize(**options)
    depends_on "my_provider_gem"  # Only loaded when provider is used

    @client = ::MyProviderGem::Client.new(**options)
  end
end
```

## Registering Your Provider

Register your provider under an identifier — from an initializer or anywhere during boot:

```ruby
Riffer::Providers::Repository.register(:my_provider) { Riffer::Providers::MyProvider }
```

The block resolves the provider class lazily, so it need not be loaded at registration time. Registration is idempotent — re-registering the same identifier replaces the previous factory — and a custom registration takes precedence over a built-in sharing the identifier, which lets you route an existing prefix (e.g. `openai`) through your own backend. Both `find` and `key_for` (used for pricing and observability keys) honor the registration. Remove one with `Riffer::Providers::Repository.unregister(:my_provider)`.

## Using Your Provider

```ruby
class MyAgent < Riffer::Agent
  model 'my_provider/model-name'
end
```

## Tool Support

Tools are converted in `build_request_params` and passed through to both `execute_generate` and `execute_stream`:

```ruby
def build_request_params(messages, model, options)
  tools = options[:tools]

  params = {
    model: model,
    messages: convert_messages(messages)
  }

  if tools && !tools.empty?
    params[:tools] = tools.map { |t| convert_tool(t) }
  end

  params
end

def convert_tool(tool)
  {
    name: tool.name,
    description: tool.description,
    parameters: tool.parameters_schema
  }
end
```

## Stream Events

Use the appropriate stream event classes in `execute_stream`:

```ruby
# Text streaming
Riffer::StreamEvents::TextDelta.new("chunk of text")
Riffer::StreamEvents::TextDone.new("complete text")

# Tool calls
Riffer::StreamEvents::ToolCallDelta.new(
  item_id: "id",
  name: "tool_name",
  arguments_delta: '{"partial":'
)
Riffer::StreamEvents::ToolCallDone.new(
  item_id: "id",
  call_id: "call_id",
  name: "tool_name",
  arguments: '{"complete":"args"}'
)

# Reasoning (if supported)
Riffer::StreamEvents::ReasoningDelta.new("thinking...")
Riffer::StreamEvents::ReasoningDone.new("complete reasoning")

# Web search (if supported)
Riffer::StreamEvents::WebSearchStatus.new("searching", query: "search query")
Riffer::StreamEvents::WebSearchDone.new(
  "search query",
  sources: [{title: "Result", url: "https://example.com"}]
)

# Token usage (emit at end of stream)
Riffer::StreamEvents::TokenUsageDone.new(
  token_usage: Riffer::Providers::TokenUsage.new(
    input_tokens: 100,
    output_tokens: 50
  )
)

# Finish reason (emit at end of stream)
Riffer::StreamEvents::FinishReasonDone.new(
  finish_reason: :stop,
  raw_finish_reason: "done"
)
```

## Token Usage Semantics

`Riffer::Providers::TokenUsage` is a normalized contract — map your provider's raw usage into the bucket meanings defined in [Messages — Token Usage Semantics](../08_MESSAGES.md#token-usage-semantics) rather than passing fields through untouched.

## Finish Reasons

`Riffer::Providers::FinishReason` is the same kind of normalized contract — map your provider's raw finish/stop value into the vocabulary defined in [Messages — Finish Reasons](../08_MESSAGES.md#finish-reasons) (`:stop`, `:length`, `:tool_calls`, `:content_filter`, `:error`, `:other`), keeping the raw wire value alongside:

```ruby
def extract_finish_reason(response)
  raw = response.stop_reason
  return nil unless raw

  Riffer::Providers::FinishReason.new(
    reason: {"done" => :stop, "max_len" => :length}.fetch(raw, :other),
    raw: raw
  )
end
```

The hook is optional — the base class defaults to `nil` (no finish reason reported). Map unmapped values to `:other`, never raise on a novel wire value.

For streaming, emit a `FinishReasonDone` event near the end of `execute_stream`:

```ruby
yielder << Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :stop, raw_finish_reason: "done")
```

## Trace Provider Name

LLM-call and agent-run spans stamp `gen_ai.provider.name` from the `semconv_provider_name` class method. The default is your snake_cased class name; override it when a [GenAI semconv well-known value](https://opentelemetry.io/docs/specs/semconv/gen-ai/) exists for your provider:

```ruby
def self.semconv_provider_name
  "my_provider"
end
```

## Error Handling

Raise appropriate Riffer errors:

```ruby
def extract_assistant_message(response, token_usage = nil)
  content = response.content
  raise Riffer::Error, "No content returned from provider" if content.nil? || content.empty?

  Riffer::Messages::Assistant.new(content, token_usage: token_usage)
rescue MyProviderGem::AuthError => e
  raise Riffer::ArgumentError, "Authentication failed: #{e.message}"
end
```

## Complete Example

```ruby
# lib/riffer/providers/my_provider.rb

class Riffer::Providers::MyProvider < Riffer::Providers::Base
  def initialize(**options)
    depends_on "my_provider_gem"

    api_key = options[:api_key] || ENV["MY_PROVIDER_API_KEY"]
    @client = ::MyProviderGem::Client.new(api_key: api_key)
  end

  private

  # Hook methods

  def build_request_params(messages, model, options)
    system_message = extract_system(messages)
    conversation = messages.reject { |m| m.is_a?(Riffer::Messages::System) }
    tools = options[:tools]

    params = {
      model: model,
      messages: convert_messages(conversation),
      system: system_message,
      max_tokens: options[:max_tokens] || 4096,
      **options.except(:tools, :max_tokens)
    }

    if tools && !tools.empty?
      params[:tools] = tools.map { |t| convert_tool(t) }
    end

    params
  end

  def execute_generate(params)
    @client.create(**params)
  end

  def execute_stream(params, yielder)
    accumulated_text = ""

    @client.stream(**params) do |event|
      case event.type
      when :text_delta
        accumulated_text += event.text
        yielder << Riffer::StreamEvents::TextDelta.new(event.text)
      when :message_stop
        yielder << Riffer::StreamEvents::TextDone.new(accumulated_text)
      when :usage
        yielder << Riffer::StreamEvents::TokenUsageDone.new(
          token_usage: Riffer::Providers::TokenUsage.new(
            input_tokens: event.usage.input_tokens,
            output_tokens: event.usage.output_tokens
          )
        )
      end
    end
  end

  def extract_token_usage(response)
    usage = response.usage
    return nil unless usage

    Riffer::Providers::TokenUsage.new(
      input_tokens: usage.input_tokens,
      output_tokens: usage.output_tokens
    )
  end

  def extract_assistant_message(response, token_usage = nil)
    text = ""
    tool_calls = []

    response.content.each do |block|
      case block.type
      when "text"
        text = block.text
      when "tool_use"
        tool_calls << Riffer::Messages::Assistant::ToolCall.new(
          id: block.id,
          call_id: block.id,
          name: block.name,
          arguments: block.input.to_json
        )
      end
    end

    raise Riffer::Error, "No content returned from provider" if text.empty? && tool_calls.empty?

    Riffer::Messages::Assistant.new(text, tool_calls: tool_calls, token_usage: token_usage)
  end

  # Helper methods

  def extract_system(messages)
    system_msg = messages.find { |m| m.is_a?(Riffer::Messages::System) }
    system_msg&.content
  end

  def convert_messages(messages)
    messages.map do |msg|
      case msg
      when Riffer::Messages::User
        {role: "user", content: msg.content}
      when Riffer::Messages::Assistant
        {role: "assistant", content: msg.content}
      when Riffer::Messages::Tool
        {role: "user", content: [{type: "tool_result", tool_use_id: msg.tool_call_id, content: msg.content}]}
      end
    end
  end

  def convert_tool(tool)
    {
      name: tool.name,
      description: tool.description,
      input_schema: tool.parameters_schema
    }
  end
end
```
