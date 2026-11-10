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
    required :city, :string, description: "The city name"
    optional :units, :string, default: "celsius", enum: ["celsius", "fahrenheit"]
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
    required :product_id, :integer, description: "The product ID"
    required :quantity, :integer, description: "Number of items"
    optional :notes, :string, description: "Order notes"
    optional :priority, :string, default: "normal", enum: ["low", "normal", "high"]
  end
end
```

## Parameter DSL

### required

Defines a required parameter:

```ruby
params do
  required :name, :string, description: "The user's name"
  required :age, :integer, description: "The user's age"
end
```

Options:

- `description` - Human-readable description for the LLM
- `enum` - Array of allowed values (for the innermost items of an `:array` with `of:`)
- `format` - String format such as `"date"` or `"email"` (for the innermost `:string` items of an `:array`; see [Formats](AGENTS.md#formats))

### optional

Defines an optional parameter:

```ruby
params do
  optional :limit, :integer, default: 10, description: "Max results"
  optional :format, :string, enum: ["json", "xml"], description: "Output format"
end
```

Options:

- `description` - Human-readable description
- `default` - Default value when not provided
- `enum` - Array of allowed values (for the innermost items of an `:array` with `of:`)
- `format` - String format such as `"date"` or `"email"` (for the innermost `:string` items of an `:array`; see [Formats](AGENTS.md#formats))

### Supported Types

| Type       | JSON Schema type                 | Validated value                   | Deprecated class                                     |
| ---------- | -------------------------------- | --------------------------------- | ---------------------------------------------------- |
| `:string`  | `string`                         | `String`                          | `String`                                             |
| `:integer` | `integer`                        | `Integer`                         | `Integer`                                            |
| `:number`  | `number`                         | `Float`                           | `Float`                                              |
| `:boolean` | `boolean`                        | `true` or `false`                 | `Riffer::Params::Boolean`, `TrueClass`, `FalseClass` |
| `:array`   | `array`                          | `Array`                           | `Array`                                              |
| `:object`  | `object`                         | `Hash` with symbol keys           | `Hash`                                               |
| `:any_of`  | `anyOf` of objects or primitives | The value of the matching variant | `Riffer::Params::AnyOf`                              |

`required`, `optional`, `of:` and `variant` still accept the deprecated Ruby classes, and each line that uses one reports a [deprecation](CONFIGURATION.md#deprecations). They won't be removed before 1 December 2026.

A `:number` param accepts a whole number too, since JSON Schema's `number` covers integers — a model returning `120` for a `:number` is valid, and the validated value is coerced to `120.0`. `:integer` stays strict: `1.0` is rejected, matching JSON Schema's `integer`.

### Nested Parameters

Tool params support the same nested DSL as structured output — nested objects (`:object` with block), typed arrays (`:array, of:`), arrays of arrays (`:array, of: [:integer]`), arrays of objects (`:array` with block), and either/or shapes (`:any_of` with `variant`s). See the [structured output section in Agents](AGENTS.md#nested-objects) for full syntax.

```ruby
class CreateOrderTool < Riffer::Tool
  description "Creates an order"

  params do
    required :items, :array, description: "Line items" do
      required :product_id, :integer
      required :quantity, :integer
      optional :notes, :string
    end
    required :shipping, :object, description: "Shipping address" do
      required :street, :string
      required :city, :string
      optional :zip, :string
    end
  end

  def call(context:, items:, shipping:)
    # items is an Array of Hashes with symbolized keys
    # shipping is a Hash with symbolized keys
  end
end
```

## Looking Up Tools

Look up a tool by identifier with `Riffer::Tool.find`, or list every tool with `Riffer::Tool.all`:

```ruby
Riffer::Tool.find('kb_search')   # => SearchTool
Riffer::Tool.find(:kb_search)    # symbols work too
Riffer::Tool.find('missing')     # => nil
Riffer::Tool.all                 # => [SearchTool, ...]
```

Only **named direct subclasses** are found implicitly:

- Grandchildren are not visible to a grandparent's `find` or `all`. If your app defines an intermediate base class (`class ApplicationTool < Riffer::Tool`), call `find`/`all` on the intermediate class to look up its subclasses.
- Anonymous classes (`Class.new(Riffer::Tool)`) are never findable implicitly, even when they set an explicit `identifier` — see [Registering a tool explicitly](#registering-a-tool-explicitly).
- Two subclasses sharing an identifier raise `Riffer::DuplicateIdentifierError` at the first lookup.
- A subclass whose constant no longer points at it — after a Zeitwerk reload or an RSpec `stub_const` — drops out of `find` and `all`. The check runs when the registry is rebuilt, which defining, registering, or unregistering a subclass triggers; removing or restoring a constant on its own does not, so lookups keep returning the old class until the next rebuild.

### Registering a tool explicitly

**Testing a tool that gets resolved by identifier? Use [`Riffer::Testing`](TESTING.md)** — `stub_tool` builds and registers a throwaway tool and cleans it up for you. The API below is the manual alternative, for production wiring and anything outside the stub lifecycle.

`register` adds a tool to its parent's registry by hand and `unregister` removes it:

```ruby
Riffer::Tool.register(tool)   # findable until unregistered
Riffer::Tool.unregister(tool) # no-op if it was never registered
```

Explicit registration differs from implicit in a few ways:

- Anonymous classes are allowed, as long as they declare an `identifier`. A blank identifier raises `Riffer::ArgumentError`.
- The class must be a **direct** subclass of the receiver, mirroring implicit registration. `Riffer::Tool.register(SomeAppTool)` raises `Riffer::ArgumentError` when `SomeAppTool` descends from an intermediate base — call `register` on that base instead.
- Taking an identifier already held by another tool, implicit or explicit, raises `Riffer::DuplicateIdentifierError`. Re-registering the same class raises too; there is no idempotent path.
- The registration survives until you remove it — it is never dropped for a stale constant.

Registration is not synchronized. Register during boot or from a single-threaded test, before concurrent lookups begin.

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

Three keys are framework-managed and exposed as typed accessors:

- `context.skills` — the resolved `Riffer::Skills::Context` when the agent has skills configured, otherwise `nil`.
- `context.token_usage` — the cumulative `Riffer::Providers::TokenUsage` across every run on the agent, or `nil` before the first response.
- `context.deferred_tools` — the agent's [deferred tools](#loading-deferred-tools-experimental), loaded or not (`[]` when it has none).

Passing your own `:deferred_tools` key in `context:` is deprecated: it still works, and `context[:deferred_tools]` returns your value, but it prints a [deprecation warning](STABILITY.md#deprecations), and a future breaking release reserves the key. Rename it.

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

If no type is specified, it defaults to `:execution_error`. Riffer reserves `:unhandled_error` for unrescued exceptions, and `:invalid_tool_load` and `:tool_not_loaded` for [deferred tools](#loading-deferred-tools-experimental) — don't set them yourself.

### Using Riffer::Tools::Response Directly

The shorthand methods delegate to `Riffer::Tools::Response`. You can also use the class directly if preferred:

```ruby
Riffer::Tools::Response.text("Hello")
Riffer::Tools::Response.json({data: [1, 2, 3]})
Riffer::Tools::Response.error("Failed", type: :custom_error)
Riffer::Tools::Response.load_tools([ListEvents])
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
error_response.exception      # => nil
```

`exception` holds the rescued exception on the `:unhandled_error` responses Riffer builds. It never appears in serialized output, so it is not visible to the LLM.

## Loading deferred tools (experimental)

An agent can hold tools back with [`deferred_tools`](AGENTS.md#deferred_tools-experimental). Any of its own tools loads them by returning `load_tools(tools)`, and `context.deferred_tools` lists the tools it can choose from. A search tool, a browse tool or a "connect your calendar" tool is an ordinary tool:

```ruby
class FindTools < Riffer::Tool
  description "Find more tools for a task. Describe what you need to do in a few words."
  params { required :query, String }

  def call(context:, query:)
    words = query.downcase.split
    matches = context.deferred_tools.select { |tool| words.any? { |w| tool.description.downcase.include?(w) } }
    load_tools(matches.first(5))
  end
end

class ConnectCalendar < Riffer::Tool
  description "Connect the user's calendar. Calendar tools become available afterwards."

  def call(context:)
    Calendars.connect!(context[:user])
    load_tools([ListEvents, CreateEvent])
  end
end
```

A load takes effect from the model's next turn. The model made every call in a turn before it saw any of that turn's results, so a call to a tool loaded in the same turn is refused like any other unloaded call; the model calls it again once it has seen the load.

- A load can't carry text as well, because Anthropic rejects a tool result that mixes loaded tools with text. `load_tools` takes no text, and the response's `content` is `""`.
- `load_tools([])` is a successful load of nothing.
- Loading a tool that isn't one of the agent's deferred tools, including one in `uses_tools`, returns an `:invalid_tool_load` error to the model instead, and nothing in that load is loaded.
- Loading a tool that's already loaded succeeds and changes nothing: the tool is loaded once, and stays loaded for the rest of the conversation. Tools can't be unloaded.
- A call to a deferred tool that hasn't been loaded isn't run. The model gets an error result of type `:tool_not_loaded` (`Tool 'list_events' has not been loaded`). Riffer checks this itself, before the [tool runtime](TOOL_ADVANCED.md#tool-runtime) sees the call, so a custom runtime can't run an unloaded tool by mistake. That includes a call forced by a provider's own `tool_choice` passed through `model_options`, and an unloaded call already in a restored history.

`response.loaded_tools` returns the tools a response loads, and is `[]` on every other response. Riffer records the loaded tools' names on the [tool message](MESSAGES.md#tool) as `loaded_tools`.

Loading puts the loaded tools' full schemas into the conversation, and every load is an extra round trip to the model, so load a handful of tools at a time rather than dozens.
