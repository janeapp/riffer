# Creating Custom Providers

You can create custom providers to connect Riffer to other LLM services.

## Basic Structure

Extend `Riffer::Providers::Base` and implement the required methods:

```ruby
class Riffer::Providers::MyProvider < Riffer::Providers::Base
  def initialize(**options)
    # Initialize your client
    @api_key = options[:api_key] || ENV['MY_PROVIDER_API_KEY']
    @client = MyProviderClient.new(api_key: @api_key)
  end

  private

  def perform_generate_text(messages, model:, **options)
    # Convert messages to provider format
    formatted = convert_messages(messages)

    # Call your provider's API
    response = @client.generate(
      model: model,
      messages: formatted,
      **options
    )

    # Return a Riffer::Messages::Assistant
    Riffer::Messages::Assistant.new(
      response.text,
      tool_calls: extract_tool_calls(response)
    )
  end

  def perform_stream_text(messages, model:, **options)
    Enumerator.new do |yielder|
      formatted = convert_messages(messages)

      @client.stream(model: model, messages: formatted, **options) do |chunk|
        # Yield appropriate stream events
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
  end

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
    # Handle tool calls if present
    {role: "assistant", content: msg.content, tool_calls: msg.tool_calls}
  end

  def extract_tool_calls(response)
    return [] unless response.tool_calls

    response.tool_calls.map do |tc|
      {
        id: tc.id,
        call_id: tc.id,
        name: tc.name,
        arguments: tc.arguments
      }
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

Add your provider to the repository:

```ruby
# In lib/riffer/providers/repository.rb or your own code

Riffer::Providers::Repository::REPO[:my_provider] = -> { Riffer::Providers::MyProvider }
```

Or create a custom repository:

```ruby
module MyApp
  module Providers
    def self.find(identifier)
      case identifier.to_sym
      when :my_provider
        Riffer::Providers::MyProvider
      else
        Riffer::Providers::Repository.find(identifier)
      end
    end
  end
end
```

## Using Your Provider

```ruby
class MyAgent < Riffer::Agent
  model 'my_provider/model-name'
end
```

## Tool Support

Convert tools to your provider's format:

```ruby
def perform_generate_text(messages, model:, tools: nil, **options)
  params = {
    model: model,
    messages: convert_messages(messages)
  }

  if tools && !tools.empty?
    params[:tools] = tools.map { |t| convert_tool(t) }
  end

  response = @client.generate(**params)
  # ...
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

Use the appropriate stream event classes:

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
```

## Error Handling

Raise appropriate Riffer errors:

```ruby
def perform_generate_text(messages, model:, **options)
  response = @client.generate(...)

  if response.error?
    raise Riffer::Error, "Provider error: #{response.error_message}"
  end

  # ...
rescue MyProviderGem::AuthError => e
  raise Riffer::ArgumentError, "Authentication failed: #{e.message}"
end
```

## Complete Example

```ruby
# lib/riffer/providers/anthropic.rb

class Riffer::Providers::Anthropic < Riffer::Providers::Base
  def initialize(**options)
    depends_on "anthropic"

    api_key = options[:api_key] || ENV['ANTHROPIC_API_KEY']
    @client = ::Anthropic::Client.new(api_key: api_key)
  end

  private

  def perform_generate_text(messages, model:, tools: nil, **options)
    system_message = extract_system(messages)
    conversation = messages.reject { |m| m.is_a?(Riffer::Messages::System) }

    params = {
      model: model,
      messages: convert_messages(conversation),
      system: system_message,
      max_tokens: options[:max_tokens] || 4096
    }

    if tools && !tools.empty?
      params[:tools] = tools.map { |t| convert_tool(t) }
    end

    response = @client.messages.create(**params)
    extract_assistant_message(response)
  end

  def perform_stream_text(messages, model:, tools: nil, **options)
    Enumerator.new do |yielder|
      # Similar implementation with streaming
    end
  end

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

  def extract_assistant_message(response)
    text = ""
    tool_calls = []

    response.content.each do |block|
      case block.type
      when "text"
        text = block.text
      when "tool_use"
        tool_calls << {
          id: block.id,
          call_id: block.id,
          name: block.name,
          arguments: block.input.to_json
        }
      end
    end

    Riffer::Messages::Assistant.new(text, tool_calls: tool_calls)
  end
end
```
