# Agents

Agents are the central orchestrator in Riffer. They manage the conversation flow, call LLM providers, and handle tool execution.

## When to Use Agents

Use an agent when the task is open-ended and the LLM needs to reason, iterate, or call tools to produce a result. If your task follows a fixed sequence of steps with no LLM decision-making, consider a simpler pipeline instead.

## Defining an Agent

Create an agent by subclassing `Riffer::Agent`:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are a helpful assistant.'
end
```

## Configuration Methods

### model

Sets the provider and model in `provider/model` format:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'           # OpenAI
  # or
  model 'amazon_bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0'  # Bedrock
  # or
  model 'mock/any'                # Mock provider
end
```

Models can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model -> { "anthropic/claude-haiku-4-5-20251001" }
end
```

When the lambda accepts a parameter, it receives the `context`:

```ruby
class MyAgent < Riffer::Agent
  model ->(context) {
    context&.dig(:premium) ? "anthropic/claude-sonnet-4-5-20250929" : "anthropic/claude-haiku-4-5-20251001"
  }
end
```

The lambda is re-evaluated on each `generate` or `stream` call, so the model can change between calls based on runtime context.

### instructions

Sets system instructions for the agent:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are an expert Ruby programmer. Provide concise answers.'
end
```

Instructions can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions -> { "Today is #{Date.today}. You are a helpful assistant." }
end
```

When the lambda accepts a parameter, it receives the `context`:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions ->(ctx) { "You are assisting #{ctx[:name]}" }
end

MyAgent.generate('Hello!', context: { name: 'Jane' })
```

The lambda is re-evaluated on each `generate` or `stream` call, so instructions can change between calls based on runtime context.

### identifier

Sets a custom identifier (defaults to snake_case class name):

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  identifier 'custom_agent_name'
end

MyAgent.identifier  # => "custom_agent_name"
```

### uses_tools

Registers tools the agent can use:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, TimeTool]
end
```

Tools can also be resolved dynamically with a lambda:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

  uses_tools ->(context) {
    tools = [PublicTool]
    tools << AdminTool if context&.dig(:user)&.admin?
    tools
  }
end
```

### use_mcp

Loads tools from registered [MCP](14_MCP.md) servers by tag. Like `uses_tools`, **`use_mcp` is not inherited**—add it on each subclass that should include MCP tools.

### provider_options

Passes options to the provider client:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  provider_options api_key: ENV['CUSTOM_OPENAI_KEY']
end
```

### model_options

Passes options to each LLM request:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  model_options reasoning: 'medium', temperature: 0.7, web_search: true
end
```

### max_steps

Sets the maximum number of LLM call steps in the tool-use loop. When the limit is reached, the loop interrupts with reason `:max_steps`. Defaults to `16`. Set to `Float::INFINITY` for unlimited steps:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  max_steps 8
end
```

### structured_output

Configures the agent to return structured JSON responses conforming to a schema. Accepts a `Riffer::Params` instance or a block DSL:

```ruby
class SentimentAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'Analyze the sentiment of the given text.'
  structured_output do
    required :sentiment, String, description: "positive, negative, or neutral"
    required :score, Float, description: "Confidence score between 0 and 1"
    optional :explanation, String, description: "Brief explanation"
  end
end
```

The LLM response is automatically parsed and validated against the schema. Access the result via `response.structured_output`.

#### Nested Objects

Use `Hash` with a block to define nested object schemas:

```ruby
structured_output do
  required :name, String, description: "Person name"
  required :address, Hash, description: "Mailing address" do
    required :street, String, description: "Street address"
    required :city, String, description: "City"
    optional :postal_code, String, description: "Postal or zip code"
  end
end
```

Validation errors use dot-path notation: `address.city is required`.

#### Typed Arrays

Use `Array` with the `of:` keyword for arrays of primitive types:

```ruby
structured_output do
  required :tags, Array, of: String, description: "Tags"
  required :scores, Array, of: Float, description: "Scores"
end
```

Only primitive types are allowed with `of:`: `String`, `Integer`, `Float`, `TrueClass`, `FalseClass`.

#### Arrays of Objects

Use `Array` with a block to define arrays of objects:

```ruby
structured_output do
  required :items, Array, description: "Line items" do
    required :name, String, description: "Product name"
    required :price, Float, description: "Price"
    optional :quantity, Integer, description: "Quantity"
  end
end
```

Validation errors include the array index: `items[1].price is required`.

#### Deep Nesting

Blocks can be nested arbitrarily deep:

```ruby
structured_output do
  required :orders, Array, description: "Orders" do
    required :id, String, description: "Order ID"
    required :shipping, Hash, description: "Shipping info" do
      required :address, Hash, description: "Address" do
        required :street, String
        required :city, String
      end
    end
  end
end
```

#### Limitations

Using both `of:` and a block raises `Riffer::ArgumentError`. Using `of:` with a non-primitive type (e.g. `of: Hash`) also raises `Riffer::ArgumentError`.

Structured output is not compatible with streaming — calling `stream` on an agent with structured output configured raises `Riffer::ArgumentError`.

### tool_runtime (Experimental)

> **Warning:** This feature is experimental and may be removed or changed without warning in a future release.

Configures how tool calls are executed. Defaults to sequential (inline) execution:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime Riffer::ToolRuntime::Threaded
end
```

Accepts a `Riffer::ToolRuntime` subclass, a `Riffer::ToolRuntime` instance, or a `Proc`. Inherited by subclasses. When unset, falls back to `Riffer.config.tool_runtime`. See [Tools — Tool Runtime](07_TOOL_ADVANCED.md#tool-runtime-experimental) for details.

### guardrail

Registers guardrails for pre/post processing of messages. Pass the guardrail class and any options:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

  # Input-only guardrail
  guardrail :before, with: InputValidator

  # Output-only guardrail
  guardrail :after, with: ResponseFilter

  # Both input and output, with options
  guardrail :around, with: MaxLengthGuardrail, max: 1000
end
```

See [Guardrails](12_GUARDRAILS.md) for detailed documentation.

## Expand Your Agent

| Goal                          | Feature           | Guide                                                                |
| ----------------------------- | ----------------- | -------------------------------------------------------------------- |
| Call APIs or run functions    | Tools             | [Tools](06_TOOLS.md)                                                 |
| Return structured JSON        | Structured Output | [structured_output](#structured_output)                              |
| Validate or filter content    | Guardrails        | [Guardrails](12_GUARDRAILS.md)                                       |
| Measure output quality        | Evals             | [Evals](11_EVALS.md)                                                 |
| Add packaged capabilities     | Skills            | [Skills](13_SKILLS.md)                                               |
| Control the tool-use loop     | Agent Loop        | [Agent Loop](05_AGENT_LOOP.md)                                       |
| Human-in-the-loop approval    | Interrupts        | [Agent Lifecycle](04_AGENT_LIFECYCLE.md#interrupting-the-agent-loop) |
| Run tools concurrently        | Tool Runtime      | [Advanced Tools](07_TOOL_ADVANCED.md#tool-runtime-experimental)      |
| Stream responses in real time | Streaming         | [Agent Lifecycle](04_AGENT_LIFECYCLE.md#stream)                      |
