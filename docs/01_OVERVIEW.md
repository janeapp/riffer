# Overview

Riffer is a Ruby framework for building AI-powered applications and agents. It provides a complete toolkit for integrating Large Language Models (LLMs) into your Ruby projects.

## Core Concepts

### Agent

The Agent is the central orchestrator for AI interactions. It manages messages, calls the LLM provider, and handles tool execution.

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
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
    text(WeatherAPI.fetch(city))
  end
end
```

See [Tools](06_TOOLS.md) for details.

### Structured Output

Agents can return structured JSON responses that conform to a schema. The response is automatically parsed and validated. Schemas support nested objects (`Hash`), typed arrays (`Array, of:`), and arrays of objects (`Array` with block):

```ruby
class SentimentAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  structured_output do
    required :sentiment, String
    required :score, Float
    required :entities, Array, description: "Named entities" do
      required :name, String
      required :type, String, enum: ["person", "place", "org"]
    end
  end
end

response = SentimentAgent.generate('Analyze: "I love this!"')
response.structured_output  # => {sentiment: "positive", score: 0.95, entities: [...]}
```

See the [structured output section in Agents](03_AGENTS.md#structured_output) for details.

### Provider

Providers are adapters that connect to LLM services. Riffer supports:

- **OpenAI** - GPT models via the OpenAI API
- **Azure OpenAI** - GPT models via Azure
- **Amazon Bedrock** - Claude and other models via AWS Bedrock
- **Anthropic** - Claude models via the Anthropic API
- **Mock** - Mock provider for testing

See [Providers](providers/01_PROVIDERS.md) for details.

### Messages

Messages represent the conversation between user and assistant. Riffer uses strongly-typed message objects:

- `Riffer::Messages::System` - System instructions
- `Riffer::Messages::User` - User input
- `Riffer::Messages::Assistant` - LLM responses
- `Riffer::Messages::Tool` - Tool execution results

See [Messages](08_MESSAGES.md) for details.

### Stream Events

When streaming responses, Riffer emits typed events:

- `TextDelta` - Incremental text chunks
- `TextDone` - Complete text
- `ToolCallDelta` - Incremental tool call arguments
- `ToolCallDone` - Complete tool call
- `WebSearchStatus` - Web search progress updates
- `WebSearchDone` - Web search completion with sources

See [Stream Events](09_STREAM_EVENTS.md) for details.

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
- [Tools](06_TOOLS.md) - Creating tools
- [Configuration](10_CONFIGURATION.md) - Global configuration
- [Tracing](16_TRACING.md) - OpenTelemetry span contract and host wiring
- [Events](17_EVENTS.md) - Event bus and schema for driving metrics, logs, and other observability
- [Evals](11_EVALS.md) - Evaluating agent quality
- [Guardrails](12_GUARDRAILS.md) - Input/output validation
- [Skills](13_SKILLS.md) - Packaged agent capabilities
- [Serialization](15_SERIALIZATION.md) - Persisting and transferring agent definitions
