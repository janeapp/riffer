# Tools

Tools are callable functions that agents can invoke to interact with external systems, fetch data, or perform actions.

## Defining a Tool

Create a tool by subclassing `Riffer::Tool`:

```ruby
class WeatherTool < Riffer::Tool
  description "Gets the current weather for a city"

  params do
    required :city, String, description: "The city name"
    optional :units, String, default: "celsius", enum: ["celsius", "fahrenheit"]
  end

  def call(context:, city:, units: nil)
    weather = WeatherAPI.fetch(city, units: units || "celsius")
    text("The weather in #{city} is #{weather.temperature} #{units}.")
  end
end
```

## Configuration Methods

### description

Sets a description that helps the LLM understand when to use the tool:

```ruby
class SearchTool < Riffer::Tool
  description "Searches the knowledge base for relevant information"
end
```

### identifier / name

Sets a custom identifier (defaults to snake_case class name):

```ruby
class SearchTool < Riffer::Tool
  identifier 'kb_search'
end

SearchTool.identifier  # => "kb_search"
SearchTool.name        # => "kb_search" (alias)
```

### params

Defines the tool's parameters using a DSL:

```ruby
class CreateOrderTool < Riffer::Tool
  params do
    required :product_id, Integer, description: "The product ID"
    required :quantity, Integer, description: "Number of items"
    optional :notes, String, description: "Order notes"
    optional :priority, String, default: "normal", enum: ["low", "normal", "high"]
  end
end
```

## Parameter DSL

### required

Defines a required parameter:

```ruby
params do
  required :name, String, description: "The user's name"
  required :age, Integer, description: "The user's age"
end
```

Options:

- `description` - Human-readable description for the LLM
- `enum` - Array of allowed values

### optional

Defines an optional parameter:

```ruby
params do
  optional :limit, Integer, default: 10, description: "Max results"
  optional :format, String, enum: ["json", "xml"], description: "Output format"
end
```

Options:

- `description` - Human-readable description
- `default` - Default value when not provided
- `enum` - Array of allowed values

### Supported Types

| Ruby Type                  | JSON Schema Type |
| -------------------------- | ---------------- |
| `String`                   | `string`         |
| `Integer`                  | `integer`        |
| `Float`                    | `number`         |
| `Riffer::Boolean`          | `boolean`        |
| `TrueClass` / `FalseClass` | `boolean`        |
| `Array`                    | `array`          |
| `Hash`                     | `object`         |

`Riffer::Boolean` is the preferred way to declare boolean parameters. `TrueClass` and `FalseClass` continue to work for backwards compatibility.

### Nested Parameters

Tool params support the same nested DSL as structured output — nested objects (`Hash` with block), typed arrays (`Array, of:`), and arrays of objects (`Array` with block). See the [structured output section in Agents](03_AGENTS.md#nested-objects) for full syntax.

```ruby
class CreateOrderTool < Riffer::Tool
  description "Creates an order"

  params do
    required :items, Array, description: "Line items" do
      required :product_id, Integer
      required :quantity, Integer
      optional :notes, String
    end
    required :shipping, Hash, description: "Shipping address" do
      required :street, String
      required :city, String
      optional :zip, String
    end
  end

  def call(context:, items:, shipping:)
    # items is an Array of Hashes with symbolized keys
    # shipping is a Hash with symbolized keys
  end
end
```

## The call Method

Every tool must implement the `call` method and return a `Riffer::Tools::Response`:

```ruby
def call(context:, **kwargs)
  # context - The tool_context passed to agent.generate()
  # kwargs  - Validated parameters
  #
  # Must return a Riffer::Tools::Response
end
```

### Accessing Context

The `context` argument receives whatever was passed to `tool_context`:

```ruby
class UserOrdersTool < Riffer::Tool
  description "Gets the current user's orders"

  def call(context:)
    user_id = context&.dig(:user_id)
    unless user_id
      return error("No user ID provided")
    end

    orders = Order.where(user_id: user_id)
    text(orders.map(&:to_s).join("\n"))
  end
end

# Usage
agent.generate("Show my orders", tool_context: {user_id: 123})
```

## Response Objects

All tools must return a `Riffer::Tools::Response` object from their `call` method. Riffer::Tool provides shorthand methods for creating responses.

### Success Responses

Use `text` for string responses and `json` for structured data:

```ruby
def call(context:, query:)
  results = Database.search(query)

  if results.empty?
    text("No results found for '#{query}'")
  else
    text(results.map { |r| "- #{r.title}: #{r.summary}" }.join("\n"))
  end
end
```

#### text

Converts the result to a string via `to_s`:

```ruby
text("Hello, world!")
# => content: "Hello, world!"

text(42)
# => content: "42"
```

#### json

Converts the result to JSON via `to_json`:

```ruby
json({name: "Alice", age: 30})
# => content: '{"name":"Alice","age":30}'

json([1, 2, 3])
# => content: '[1,2,3]'
```

### Error Responses

Use `error(message, type:)` for errors:

```ruby
def call(context:, user_id:)
  user = User.find_by(id: user_id)

  unless user
    return error("User not found", type: :not_found)
  end

  text("User: #{user.name}")
end
```

The error type is any symbol that describes the error category:

```ruby
error("Invalid input", type: :validation_error)
error("Service unavailable", type: :service_error)
error("Rate limit exceeded", type: :rate_limit)
```

If no type is specified, it defaults to `:execution_error`.

### Using Riffer::Tools::Response Directly

The shorthand methods delegate to `Riffer::Tools::Response`. You can also use the class directly if preferred:

```ruby
Riffer::Tools::Response.text("Hello")
Riffer::Tools::Response.json({data: [1, 2, 3]})
Riffer::Tools::Response.error("Failed", type: :custom_error)
```

### Response Methods

```ruby
response = text("result")
response.content        # => "result"
response.success?       # => true
response.error?         # => false
response.error_message  # => nil
response.error_type     # => nil

error_response = error("failed", type: :not_found)
error_response.content        # => "failed"
error_response.success?       # => false
error_response.error?         # => true
error_response.error_message  # => "failed"
error_response.error_type     # => :not_found
```

## Timeout Configuration

Configure timeouts to prevent tools from running indefinitely. The default timeout is 10 seconds.

```ruby
class SlowExternalApiTool < Riffer::Tool
  description "Calls a slow external API"
  timeout 30  # 30 seconds

  def call(context:, query:)
    result = ExternalAPI.search(query)
    text(result)
  end
end
```

When a tool times out, the error is reported to the LLM with error type `:timeout_error`, allowing it to respond appropriately (e.g., suggest retrying or using a different approach).

## Validation

Arguments are automatically validated before `call` is invoked:

- Required parameters must be present
- Types must match the schema
- Enum values must be in the allowed list

Validation errors are captured and sent back to the LLM as tool results with error type `:validation_error`.

## JSON Schema Generation

Riffer automatically generates JSON Schema for each tool:

```ruby
WeatherTool.parameters_schema
# => {
#   type: "object",
#   properties: {
#     "city" => {type: "string", description: "The city name"},
#     "units" => {type: "string", enum: ["celsius", "fahrenheit"]}
#   },
#   required: ["city"],
#   additionalProperties: false
# }
```

## Registering Tools with Agents

### Static Registration

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  uses_tools [WeatherTool, SearchTool]
end
```

### Dynamic Registration

Use a lambda for context-aware tool resolution:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'

  uses_tools ->(context) {
    tools = [PublicSearchTool]

    if context&.dig(:user)&.premium?
      tools << PremiumAnalyticsTool
    end

    if context&.dig(:user)&.admin?
      tools << AdminTool
    end

    tools
  }
end
```

## Error Handling

Errors can be returned explicitly using `error`:

```ruby
def call(context:, query:)
  results = ExternalAPI.search(query)
  json(results)
rescue RateLimitError => e
  error("API rate limit exceeded, please try again later", type: :rate_limit)
rescue => e
  error("Search failed: #{e.message}")
end
```

Unhandled `RuntimeError` exceptions are caught by Riffer and converted to error responses with type `:execution_error`. For expected execution errors, raise `Riffer::ToolExecutionError` — these are also caught and returned to the LLM. Programming bugs (`NoMethodError`, `NameError`, `TypeError`, etc.) propagate to the caller. It's recommended to handle expected errors explicitly for better error messages.

The LLM receives the error message and can decide how to respond (retry, apologize, ask for different input, etc.).

## Tool Runtime (Experimental)

> **Warning:** This feature is experimental and may be removed or changed without warning in a future release.

By default, tool calls are executed sequentially in the current thread using `Riffer::ToolRuntime::Inline`. You can change how tool calls are executed by configuring a different tool runtime.

### Built-in Runtimes

| Runtime | Description |
|---------|-------------|
| `Riffer::ToolRuntime::Inline` | Executes tool calls sequentially (default) |
| `Riffer::ToolRuntime::Threaded` | Executes tool calls concurrently using threads |

### Per-Agent Configuration

Use the `tool_runtime` class method on your agent:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime :threaded
end
```

Accepted values:

- `:inline` — sequential execution (default)
- `:threaded` — concurrent execution using threads
- A `Riffer::ToolRuntime` instance — for custom runtimes
- A `Proc` — evaluated at runtime (see below)

### Dynamic Resolution

Use a lambda for context-aware runtime selection:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  uses_tools [WeatherTool, SearchTool]

  tool_runtime ->(context) {
    context&.dig(:parallel) ? :threaded : :inline
  }
end

agent.generate("Do work", tool_context: {parallel: true})
```

When the lambda accepts a parameter, it receives the `tool_context`. Zero-arity lambdas are also supported.

### Global Configuration

Set a default tool runtime for all agents:

```ruby
Riffer.configure do |config|
  config.tool_runtime = :threaded
end
```

Per-agent configuration overrides the global default.

### Threaded Runtime Considerations

When using `:threaded`, each tool call runs in its own thread. The `around_tool_call` hook also runs inside that thread. Be mindful of thread-local state — for example, `ActiveRecord::Base.connection`, `RequestStore`, or any `Thread.current[]` values may not be available or may behave differently across threads. Ensure your tools and hooks are thread-safe.

### Threaded Runtime Options

The threaded runtime accepts a `max_concurrency` option (default: 5):

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime Riffer::ToolRuntime::Threaded.new(max_concurrency: 3)
end
```

### Custom Runtimes

Create a custom runtime by subclassing `Riffer::ToolRuntime` and overriding the private `dispatch_tool_call` method:

```ruby
class HttpToolRuntime < Riffer::ToolRuntime
  private

  def dispatch_tool_call(tool_call, tools:, context:)
    # Dispatch tool execution to an external service
    response = HttpClient.post("/tools/execute", {
      name: tool_call.name,
      arguments: tool_call.arguments
    })
    Riffer::Tools::Response.text(response.body)
  rescue Riffer::ToolExecutionError => e
    Riffer::Tools::Response.error(e.message, type: :execution_error)
  rescue RuntimeError => e
    Riffer::Tools::Response.error("Error executing tool: #{e.message}", type: :execution_error)
  end
end
```

You can also compose with a custom `Riffer::Runner` for concurrency control:

```ruby
class HttpToolRuntime < Riffer::ToolRuntime
  def initialize
    super(runner: Riffer::Runner::Threaded.new(max_concurrency: 10))
  end
end
```

### Around-Call Hook

Each tool call is wrapped by the `around_tool_call` instance method, which yields by default. Use the `around_tool_call` class method DSL to define custom behavior via a symbol or block:

```ruby
# Symbol — delegates to a named instance method (recommended for non-trivial logic):
class InstrumentedRuntime < Riffer::ToolRuntime
  around_tool_call :instrument

  private

  def instrument(tool_call, context:, &block)
    start = Time.now
    result = block.call
    duration = Time.now - start
    Rails.logger.info("Tool #{tool_call.name} took #{duration}s")
    result
  end
end

# Block — for simple inline hooks:
class LoggingRuntime < Riffer::ToolRuntime
  around_tool_call do |tool_call, context:, &block|
    puts "Executing #{tool_call.name}"
    block.call
  end
end
```

You can also override `around_tool_call` directly as an instance method:

```ruby
class CustomRuntime < Riffer::ToolRuntime
  private

  def around_tool_call(tool_call, context:)
    yield
  end
end
```

Subclasses inherit the hook and can override it further.
