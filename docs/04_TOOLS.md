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
    "The weather in #{city} is #{weather.temperature} #{units}."
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

| Ruby Type | JSON Schema Type |
|-----------|------------------|
| `String`  | `string`         |
| `Integer` | `integer`        |
| `Float`   | `number`         |
| `TrueClass` / `FalseClass` | `boolean` |
| `Array`   | `array`          |
| `Hash`    | `object`         |

## The call Method

Every tool must implement the `call` method:

```ruby
def call(context:, **kwargs)
  # context - The tool_context passed to agent.generate()
  # kwargs  - Validated parameters
end
```

### Accessing Context

The `context` argument receives whatever was passed to `tool_context`:

```ruby
class UserOrdersTool < Riffer::Tool
  description "Gets the current user's orders"

  def call(context:)
    user_id = context&.dig(:user_id)
    return "No user ID provided" unless user_id

    orders = Order.where(user_id: user_id)
    orders.map(&:to_s).join("\n")
  end
end

# Usage
agent.generate("Show my orders", tool_context: {user_id: 123})
```

### Return Values

Return a string that will be sent back to the LLM:

```ruby
def call(context:, query:)
  results = Database.search(query)

  if results.empty?
    "No results found for '#{query}'"
  else
    results.map { |r| "- #{r.title}: #{r.summary}" }.join("\n")
  end
end
```

## Timeout Configuration

Configure timeouts to prevent tools from running indefinitely. The default timeout is 10 seconds.

```ruby
class SlowExternalApiTool < Riffer::Tool
  description "Calls a slow external API"
  timeout 30  # 30 seconds

  def call(context:, query:)
    ExternalAPI.search(query)
  end
end
```

When a tool times out, the error is reported to the LLM with error type `:timeout_error`, allowing it to respond appropriately (e.g., suggest retrying or using a different approach).

## Validation

Arguments are automatically validated before `call` is invoked:

- Required parameters must be present
- Types must match the schema
- Enum values must be in the allowed list

Validation errors are captured and sent back to the LLM as tool results.

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

Errors in tools are captured and reported back to the LLM:

```ruby
def call(context:, query:)
  raise "API rate limit exceeded"
rescue => e
  # Error is caught by Riffer and sent as tool result:
  # "Error executing tool: API rate limit exceeded"
end
```

The LLM can then decide how to respond (retry, apologize, ask for different input, etc.).
