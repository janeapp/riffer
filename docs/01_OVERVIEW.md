# Overview

Riffer is a Ruby framework for building AI-powered applications and agents. It provides a complete toolkit for integrating Large Language Models (LLMs) into your Ruby projects.

## Core Concepts

### Agent

The Agent is the central orchestrator for AI interactions. It manages messages, calls the LLM provider, and handles tool execution.

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  instructions 'You are a helpful assistant.'
end
```

See [Agents](03_AGENTS.md) for details.

### Tool

Tools are callable functions that agents can invoke to interact with external systems. They have structured parameter definitions and automatic validation.

```ruby
class WeatherTool < Riffer::Tool
  description "Gets the weather for a city"

  params do
    required :city, String, description: "The city name"
  end

  def call(context:, city:)
    WeatherAPI.fetch(city)
  end
end
```

See [Tools](04_TOOLS.md) for details.

### Provider

Providers are adapters that connect to LLM services. Riffer supports:

- **OpenAI** - GPT models via the OpenAI API
- **Amazon Bedrock** - Claude and other models via AWS Bedrock
- **Test** - Mock provider for testing

See [Providers](providers/01_PROVIDERS.md) for details.

### Messages

Messages represent the conversation between user and assistant. Riffer uses strongly-typed message objects:

- `Riffer::Messages::System` - System instructions
- `Riffer::Messages::User` - User input
- `Riffer::Messages::Assistant` - LLM responses
- `Riffer::Messages::Tool` - Tool execution results

See [Messages](05_MESSAGES.md) for details.

### Stream Events

When streaming responses, Riffer emits typed events:

- `TextDelta` - Incremental text chunks
- `TextDone` - Complete text
- `ToolCallDelta` - Incremental tool call arguments
- `ToolCallDone` - Complete tool call

See [Stream Events](06_STREAM_EVENTS.md) for details.

## Architecture

```
User Request
     |
     v
+------------+
|   Agent    |  <-- Manages conversation flow
+------------+
     |
     v
+------------+
|  Provider  |  <-- Calls LLM API
+------------+
     |
     v
+------------+
|    LLM     |  <-- Returns response
+------------+
     |
     v
+------------+
|   Tool?    |  <-- Execute if tool call present
+------------+
     |
     v
Response
```

## Next Steps

- [Getting Started](02_GETTING_STARTED.md) - Quick start guide
- [Agents](03_AGENTS.md) - Agent configuration and usage
- [Tools](04_TOOLS.md) - Creating tools
- [Configuration](07_CONFIGURATION.md) - Global configuration
