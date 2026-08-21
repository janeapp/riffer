# Tools

Tools are callable functions that agents can invoke to interact with external systems, fetch data, or perform actions.

## When to Use Tools

Use tools when your agent needs to fetch external data, call APIs, query databases, or perform side effects. If the agent only needs to generate text from its training data, you do not need tools.

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
| `Riffer::Params::Boolean`          | `boolean`        |
| `TrueClass` / `FalseClass` | `boolean`        |
| `Array`                    | `array`          |
| `Hash`                     | `object`         |

`Riffer::Params::Boolean` is the preferred way to declare boolean parameters. `TrueClass` and `FalseClass` continue to work for backwards compatibility.

### Nested Parameters

Tool params support the same nested DSL as structured output — nested objects (`Hash` with block), typed arrays (`Array, of:`), and arrays of objects (`Array` with block). See the [structured output section in Agents](AGENTS.md#nested-objects) for full syntax.

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

## Looking Up Tools

`Riffer::Tool.find` and `Riffer::Tool.all` are backed by a per-class registry keyed by identifier, so lookups are O(1) regardless of how many tools are defined:

```ruby
Riffer::Tool.find('kb_search')   # => SearchTool
Riffer::Tool.find(:kb_search)    # symbols work too
Riffer::Tool.find('missing')     # => nil
Riffer::Tool.all                 # => [SearchTool, ...]
```

The registry contains **named direct subclasses only**:

- Grandchildren are not visible to a grandparent's `find` or `all`. If your app defines an intermediate base class (`class ApplicationTool < Riffer::Tool`), call `find`/`all` on the intermediate class to look up its subclasses.
- Anonymous classes (`Class.new(Riffer::Tool)`) are never registered, even when they set an explicit `identifier`.
- Two registered subclasses sharing an identifier raise `Riffer::DuplicateIdentifierError` at the first lookup.

## The call Method

Every tool must implement the `call` method and return a `Riffer::Tools::Response`:

```ruby
def call(context:, **kwargs)
  # context - The context passed to agent.generate()
  # kwargs  - Validated parameters
  #
  # Must return a Riffer::Tools::Response
end
```

### Accessing Context

The `context` argument is a `Riffer::Agent::Context` — a typed value object wrapping the Hash passed as `context:` to `Agent.new`. Caller-provided keys are read with `context[:key]` or `context&.dig(:key)`:

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
MyAgent.new(context: {user_id: 123}).generate("Show my orders")
```

Two keys are framework-managed and exposed as typed accessors:

- `context.skills` — the resolved `Riffer::Skills::Context` when the agent has skills configured, otherwise `nil`.
- `context.token_usage` — the cumulative `Riffer::Providers::TokenUsage` across every run on the agent, or `nil` before the first response.

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
