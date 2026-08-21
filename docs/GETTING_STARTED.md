# Getting Started

This guide walks you through installing Riffer and creating your first AI agent.

## Installation

Add Riffer to your Gemfile:

```ruby
gem 'riffer'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install riffer
```

## Provider Setup

Riffer requires an LLM provider. See [Providers](providers/PROVIDERS.md) for setup instructions for each supported provider.

## Creating Your First Agent

Define an agent by subclassing `Riffer::Agent`:

```ruby
require 'riffer'

Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end

class GreetingAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are a friendly assistant. Greet the user warmly.'
end

agent = GreetingAgent.new
response = agent.generate('Hello!')
puts response
# => "Hello! It's wonderful to meet you..."
```

## Streaming Responses

Use `stream` for real-time output:

```ruby
agent = GreetingAgent.new

agent.stream('Tell me a story').each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::TextDone
    puts "\n[Done]"
  end
end
```

## Adding Tools

Tools let agents interact with external systems:

```ruby
class TimeTool < Riffer::Tool
  description "Gets the current time"

  def call(context:)
    text(Time.now.strftime('%Y-%m-%d %H:%M:%S'))
  end
end

class TimeAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You can tell the user the current time.'
  uses_tools [TimeTool]
end

agent = TimeAgent.new
puts agent.generate("What time is it?")
# => "The current time is 2024-01-15 14:30:00."
```

## Next Steps

- [Agents](AGENTS.md) - Agent configuration options
- [Tools](TOOLS.md) - Creating tools with parameters
- [Messages](MESSAGES.md) - Message types and history
- [Stream Events](STREAM_EVENTS.md) - Streaming event types
- [Providers](providers/PROVIDERS.md) - Provider-specific guides
