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

The lambda is evaluated once at `Agent.new` time using the context passed to the constructor. To change instructions for a new context, construct a new agent.

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

Loads tools from registered [MCP](MCP.md) servers by tag. Like `uses_tools`, **`use_mcp` is not inherited**—add it on each subclass that should include MCP tools.

### model_options

Passes options to each LLM request:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  model_options reasoning: 'medium', temperature: 0.7, web_search: true
end
```

### max_steps

Sets the maximum number of LLM call steps in the tool-use loop. When the limit is reached, the loop interrupts with reason `:max_steps`. Defaults to `16`. Set to `nil` (`max_steps nil`) for unlimited steps:

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
  tool_runtime Riffer::Tools::Runtime::Threaded
end
```

Accepts a `Riffer::Tools::Runtime` subclass, a `Riffer::Tools::Runtime` instance, or a `Proc`. When unset, defaults to `Riffer.config.tool_runtime` (captured at agent class definition time). See [Tools — Tool Runtime](TOOL_ADVANCED.md#tool-runtime-experimental) for details.

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

See [Guardrails](GUARDRAILS.md) for detailed documentation.

## Configuration Object

Every DSL setting above is stored on a `Riffer::Agent::Config` instance accessible via the class. Each subclass has its own:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  max_steps 8
end

MyAgent.config            # => #<Riffer::Agent::Config ...>
MyAgent.config.max_steps  # => 8
```

The DSL methods read and mutate this Config in place.

For advanced composition or testing, build a Config directly and pass it via `config:` to bypass class-level DSL entirely:

```ruby
config = Riffer::Agent::Config.new(
  model: 'openai/gpt-5-mini',
  instructions: 'You are a helpful assistant.',
  max_steps: 4
)

agent = Riffer::Agent.new(config: config)
agent.generate('Hello')
```

When `config:` is supplied, the class-level configuration is ignored for that instance.

## Looking Up Agents

Look up an agent by identifier with `Riffer::Agent.find`, or list every agent with `Riffer::Agent.all`. Lookups are O(1) no matter how many agents are defined:

```ruby
class SupportAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
end

Riffer::Agent.find('support_agent')   # => SupportAgent
Riffer::Agent.find(:support_agent)    # symbols work too
Riffer::Agent.find('missing')         # => nil
Riffer::Agent.all                     # => [SupportAgent, ...]
```

Only **named direct subclasses** are found:

- Grandchildren are not visible to a grandparent's `find` or `all`. If your app defines an intermediate base class (`class ApplicationAgent < Riffer::Agent`), call `find`/`all` on the intermediate class to look up its subclasses.
- Anonymous classes (`Class.new(Riffer::Agent)`) are never findable, even when they set an explicit `identifier`.
- Two subclasses sharing an identifier raise `Riffer::DuplicateIdentifierError` at the first lookup.

## Per-Call Tags

`#generate` and `#stream` accept an optional `tags:` hash — a flat map of attribution labels scoped to that single call (for cost/usage attribution, filtering audit logs, slicing telemetry). It is **per-call only**.

```ruby
agent.generate("Summarize this ticket.",
  tags: {team: "growth", feature: "summarizer", user_id: "u_abc123"})

agent.stream("...", tags: {team: "growth", environment: "production"})
```

Keys and values may be `String` or `Symbol`; both are stringified, and entries with a `nil` value are dropped. Passing a non-`Hash` raises `Riffer::ArgumentError`. An omitted or empty `tags:` is a complete no-op.

Tags propagate to **two** places:

1. The provider's native per-request metadata field (see the mapping below).
2. Observability — stamped as `riffer.tag.<key>` on **every** span the call emits (`invoke_agent`, `chat`, `execute_tool`, `execute_guardrail`). See [Tracing](TRACING.md).

### Reserved key: `user_id`

`user_id` is a reserved tag. Beyond appearing like any other tag, it maps to the provider's native end-user identifier where one exists (see the table).

### Provider mapping

| Provider              | Native request field          | `user_id` handling                      |
| --------------------- | ----------------------------- | --------------------------------------- |
| Amazon Bedrock        | `request_metadata` (all tags) | Ordinary entry; no dedicated user field |
| OpenAI / Azure OpenAI | `metadata` (all tags)         | Also mapped to `safety_identifier`      |
| OpenRouter            | `metadata` (all tags)         | Also mapped to `user`                   |
| Anthropic             | `metadata.user_id` **only**   | The only tag forwarded                  |
| Gemini                | _(none — observability only)_ | Tag only; no request field              |

**Anthropic silently drops non-`user_id` tags.** The Messages API has no free-form request-metadata field — only `metadata.user_id`. So for Anthropic, `user_id` is forwarded as `metadata: {user_id: …}` and **every other tag is dropped from the request** (it still appears on spans). This is intentional.

**Gemini is observability-only.** Riffer's Gemini adapter targets the Gemini Developer API (`generativelanguage.googleapis.com`), whose `generateContent` request has **no** `labels` field — sending unknown fields is rejected. So tags are **not** added to the Gemini request; they propagate to spans only. Native request labels (`labels`, lowercase `[a-z0-9_-]`, ≤63 chars each) are a Vertex AI feature and would arrive with a future Vertex adapter.

### Provider limits (not enforced)

Riffer does not validate tag count, key/value length, or charset — it forwards what you give it and lets the provider reject anything out of bounds. Known limits: Bedrock `requestMetadata` ≤16 entries, key/value ≤256 chars; OpenAI / OpenRouter `metadata` ≤16 pairs (OpenRouter: 64-char keys, 512-char values).

## Expand Your Agent

| Goal                          | Feature           | Guide                                                                |
| ----------------------------- | ----------------- | -------------------------------------------------------------------- |
| Call APIs or run functions    | Tools             | [Tools](TOOLS.md)                                                 |
| Return structured JSON        | Structured Output | [structured_output](#structured_output)                              |
| Validate or filter content    | Guardrails        | [Guardrails](GUARDRAILS.md)                                       |
| Measure output quality        | Evals             | [Evals](EVALS.md)                                                 |
| Add packaged capabilities     | Skills            | [Skills](SKILLS.md)                                               |
| Control the tool-use loop     | Agent Loop        | [Agent Loop](AGENT_LOOP.md)                                       |
| Human-in-the-loop approval    | Interrupts        | [Agent Lifecycle](AGENT_LIFECYCLE.md#interrupting-the-agent-loop) |
| Run tools concurrently        | Tool Runtime      | [Advanced Tools](TOOL_ADVANCED.md#tool-runtime-experimental)      |
| Stream responses in real time | Streaming         | [Agent Lifecycle](AGENT_LIFECYCLE.md#stream)                      |
