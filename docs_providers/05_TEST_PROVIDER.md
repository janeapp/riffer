# Test Provider

The Test provider is a mock provider for testing agents without making real API calls.

## Usage

No additional gems required. Use the `test` provider identifier:

```ruby
class TestableAgent < Riffer::Agent
  model 'test/any'  # The model name doesn't matter for test provider
  instructions 'You are helpful.'
  uses_tools [MyTool]
end
```

## Stubbing Responses

Use `stub_response` to queue responses:

```ruby
# Get the provider instance from the agent
agent = TestableAgent.new
provider = agent.send(:provider_instance)

# Stub a simple text response
provider.stub_response("Hello, I'm here to help!")

# Now generate will return the stubbed response
response = agent.generate("Hi")
# => "Hello, I'm here to help!"
```

## Stubbing Tool Calls

Stub responses that trigger tool execution:

```ruby
provider.stub_response("", tool_calls: [
  {name: "my_tool", arguments: '{"query":"test"}'}
])

# Queue the response after tool execution
provider.stub_response("Based on the tool result, here's my answer.")

response = agent.generate("Use the tool")
```

## Queueing Multiple Responses

Responses are consumed in order:

```ruby
provider.stub_response("First response")
provider.stub_response("Second response")
provider.stub_response("Third response")

agent.generate("Message 1")  # => "First response"
agent.generate("Message 2")  # => "Second response"
agent.generate("Message 3")  # => "Third response"
agent.generate("Message 4")  # => "Test response" (default)
```

## Inspecting Calls

Access recorded calls for assertions:

```ruby
provider.calls
# => [
#   {messages: [...], model: "any", tools: [...], ...},
#   {messages: [...], model: "any", tools: [...], ...}
# ]

# Check what was sent
expect(provider.calls.last[:messages].last[:content]).to eq("Hi")
```

## Clearing State

Reset stubbed responses:

```ruby
provider.clear_stubs
```

## Example Test

```ruby
require 'minitest/autorun'

class MyAgentTest < Minitest::Test
  def setup
    @agent = TestableAgent.new
    @provider = @agent.send(:provider_instance)
  end

  def test_generates_response
    @provider.stub_response("Hello!")

    response = @agent.generate("Hi")

    assert_equal "Hello!", response
  end

  def test_executes_tool
    @provider.stub_response("", tool_calls: [
      {name: "weather_tool", arguments: '{"city":"Tokyo"}'}
    ])
    @provider.stub_response("The weather is sunny.")

    response = @agent.generate("What's the weather?")

    assert_equal "The weather is sunny.", response
    assert_equal 2, @provider.calls.length
  end

  def test_passes_context_to_tools
    @provider.stub_response("", tool_calls: [
      {name: "user_tool", arguments: '{}'}
    ])
    @provider.stub_response("Done.")

    @agent.generate("Do something", tool_context: {user_id: 123})

    # Tool receives the context
  end
end
```

## Streaming

The test provider also supports streaming:

```ruby
provider.stub_response("Hello world.")

events = []
agent.stream("Hi").each { |e| events << e }

# Events include TextDelta and TextDone
text_deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
text_done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
```

## Initial Responses

Pass responses during initialization:

```ruby
provider = Riffer::Providers::Test.new(responses: [
  {content: "First"},
  {content: "Second"}
])
```

## Default Response

When no stubs are queued and initial responses are exhausted, the provider returns:

```ruby
{role: "assistant", content: "Test response"}
```
