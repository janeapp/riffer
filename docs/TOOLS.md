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
  params { required :query, :string }

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

How a load reaches the model depends on the agent's [strategy](AGENTS.md#deferred-tools-strategy-experimental). By default [Anthropic](providers/ANTHROPIC.md#deferred-tools), [OpenAI](providers/OPENAI.md#deferred-tools-experimental) and [Azure OpenAI](providers/AZURE_OPENAI.md#deferred-tools-experimental) load deferred tools natively; with `strategy: :gateway`, any provider goes through the [gateway](#the-gateway-strategy).

A load takes effect from the model's next turn. The model made every call in a turn before it saw any of that turn's results, so a call to a tool loaded in the same turn is refused like any other unloaded call; the model calls it again once it has seen the load.

- A load can't carry text as well, because Anthropic rejects a tool result that mixes loaded tools with text. `load_tools` takes no text, and the response's `content` is `""`.
- `load_tools([])` is a successful load of nothing.
- Loading a tool that isn't one of the agent's deferred tools, including one in `uses_tools`, returns an `:invalid_tool_load` error to the model instead, and nothing in that load is loaded.
- Loading a tool that's already loaded succeeds and changes nothing: the tool is loaded once, and stays loaded for the rest of the conversation. Tools can't be unloaded.
- A call to a deferred tool that hasn't been loaded isn't run. The model gets an error result of type `:tool_not_loaded` (`Tool 'list_events' has not been loaded`). Riffer checks this itself, before the [tool runtime](TOOL_ADVANCED.md#tool-runtime) sees the call, so a custom runtime can't run an unloaded tool by mistake. That includes a call forced by a provider's own `tool_choice` passed through `model_options`, and an unloaded call already in a restored history.

`response.loaded_tools` returns the tools a response loads, and is `[]` on every other response. Riffer records the loaded tools' names on the [tool message](MESSAGES.md#tool) as `loaded_tools`.

Loading puts the loaded tools' full schemas into the conversation, and every load is an extra round trip to the model, so load a handful of tools at a time rather than dozens.

### The gateway strategy

With `deferred_tools [...], strategy: :gateway`, riffer doesn't use the provider's native loading, so it works on every provider, custom ones included. Adding a loaded tool to the request's tools partway through a conversation would break the prompt cache on every load, so riffer keeps the tool list fixed and sends one extra tool instead, `Riffer::Providers::DeferredToolGateway::Tool`, the gateway. Its name is its default identifier, `riffer/providers/deferred_tool_gateway/tool`, which providers that encode `/` send as `riffer__providers__deferred_tool_gateway__tool`:

- Every request with deferred tools carries the gateway after the agent's other tools, before any load and after it. Its name, description and schema never change, and the deferred tools themselves are never in the tool list, so the tool list is the same for the whole conversation.
- The gateway takes two required string parameters and nothing else: `name`, the loaded tool's name, and `arguments`, the loaded tool's arguments as a JSON-encoded object (`"{\"query\":\"red shoes\",\"limit\":5}"`). Strings rather than a free-form object keep the schema valid for providers that send tools in strict mode, such as OpenRouter. Riffer still validates the arguments against the real tool's `params` when the tool runs.
- A tool result that loads tools is sent to the model with an instruction to call them through the gateway, by its wire name, appended to its content, followed by the loaded tools as one JSON array of `name`, `description` and `parameters`. The text is the same every time it is sent, so the earlier conversation doesn't change and the cache holds. Only the request carries it: the tool message in the session keeps its own content. A load that names a tool the agent no longer defers, for example in a restored history, describes nothing for that tool.
- The model's call to the gateway comes back as a call to the real tool, named by `name` with `arguments` as its arguments, before the provider returns. The session, [`on_message` callbacks](AGENT_LIFECYCLE.md#on_message), the tool runtime, the `:tool_not_loaded` check and [traces](TRACING.md) all see the real tool. A streamed gateway call yields only its `ToolCallDone`, under the real tool's name: its `ToolCallDelta` events carry pieces of the gateway's own arguments, so riffer drops them.
- On later requests, a call to a deferred tool in the history is sent back as a gateway call, and its result under the gateway's name, keeping its `tool_call_id`, so the provider never sees a call to a tool missing from the tool list.
- A gateway call riffer can't read, because its arguments aren't a JSON object with a string `name` and a string `arguments`, stays a call to the gateway, which no agent has as a tool, so the model gets an `:unknown_tool` error result and can try again.

An agent with the gateway strategy can't have a tool of its own with the gateway's name, in `uses_tools` or `deferred_tools`: building it raises `Riffer::ArgumentError`. Like the rest of deferred tools, the gateway is experimental, and its name, description and the text it adds to a load can change in any minor release.
