# Advanced Tool Configuration

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

When a tool times out, the LLM receives an error response with type `:timeout_error` and can respond appropriately (e.g., suggest retrying or using a different approach). The timeout raises `Riffer::TimeoutError` inside `call`, so a tool can rescue it to release resources before it propagates.

## Validation

Arguments are automatically validated before `call` is invoked:

- Required parameters must be present
- Types must match the schema
- Enum values must be in the allowed list

Validation errors are captured and sent back to the LLM as tool results with error type `:validation_error`, as is malformed or non-object JSON in the provider's tool-call arguments.

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
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]
end
```

### Dynamic Registration

Use a lambda for context-aware tool resolution:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

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

A tool never raises into the agent loop — every `StandardError` raised during a tool call becomes an error response:

| Failure                      | Error type          | Response content                                     |
| ---------------------------- | ------------------- | ---------------------------------------------------- |
| Invalid arguments            | `:validation_error` | the validation message                               |
| Timeout                      | `:timeout_error`    | `Tool execution timed out after N seconds`           |
| `Riffer::ToolExecutionError` | `:execution_error`  | the exception message                                |
| Any other `StandardError`    | `:unhandled_error`  | `Error executing tool: <ExceptionClass>: <message>` |

An `:unhandled_error` response also carries the rescued exception on `response.exception` — never serialized, so it stays out of the message history — and its `execute_tool` span records the exception with an `ERROR` status (see [Tracing](TRACING.md)).

`NotImplementedError` is not rescued: an unimplemented `#call` raises out of the run.

For expected failures, return `error(...)` or raise `Riffer::ToolExecutionError` — both give the LLM a clean message rather than an `:unhandled_error`.

The LLM receives the error message and can decide how to respond (retry, apologize, ask for different input, etc.).

## Tool Runtime (Experimental)

> **Warning:** This feature is experimental and may be removed or changed without warning in a future release.

By default, tool calls are executed sequentially in the current thread using `Riffer::Tools::Runtime::Inline`. You can change how tool calls are executed by configuring a different tool runtime.

### Built-in Runtimes

| Runtime                         | Description                                    |
| ------------------------------- | ---------------------------------------------- |
| `Riffer::Tools::Runtime::Inline`   | Executes tool calls sequentially (default)     |
| `Riffer::Tools::Runtime::Threaded` | Executes tool calls concurrently using threads |
| `Riffer::Tools::Runtime::Fibers`   | Executes tool calls concurrently using fibers  |

### Per-Agent Configuration

Use the `tool_runtime` class method on your agent:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime Riffer::Tools::Runtime::Threaded
end
```

Accepted values:

- A `Riffer::Tools::Runtime` subclass — instantiated automatically (e.g., `Riffer::Tools::Runtime::Inline`, `Riffer::Tools::Runtime::Threaded`)
- A `Riffer::Tools::Runtime` instance — for custom runtimes with specific options
- A `Proc` — evaluated at runtime (see below)

### Dynamic Resolution

Use a lambda for context-aware runtime selection:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]

  tool_runtime ->(context) {
    context&.dig(:parallel) ? Riffer::Tools::Runtime::Threaded.new : Riffer::Tools::Runtime::Inline.new
  }
end

MyAgent.new(context: {parallel: true}).generate("Do work")
```

When the lambda accepts a parameter, it receives the `context`. Zero-arity lambdas are also supported.

### Global Configuration

Set a default tool runtime for all agents:

```ruby
Riffer.configure do |config|
  config.tool_runtime = Riffer::Tools::Runtime::Threaded
end
```

Per-agent configuration overrides the global default.

### Threaded Runtime Considerations

When using `Riffer::Tools::Runtime::Threaded`, each tool call runs in its own thread. The `around_tool_call` hook also runs inside that thread. Be mindful of thread-local state — for example, `ActiveRecord::Base.connection`, `RequestStore`, or any `Thread.current[]` values may not be available or may behave differently across threads. Ensure your tools and hooks are thread-safe.

### Threaded Runtime Options

The threaded runtime accepts a `max_concurrency` option (default: 5):

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime Riffer::Tools::Runtime::Threaded.new(max_concurrency: 3)
end
```

### Fibers Runtime

The fibers runtime uses the [async](https://github.com/socketry/async) gem for lightweight, cooperative concurrency. It requires the `async` gem to be installed:

```ruby
# Gemfile
gem "async"
```

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime Riffer::Tools::Runtime::Fibers
end
```

By default, all tool calls run as fibers without a concurrency limit. You can optionally set a limit:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WeatherTool, SearchTool]
  tool_runtime Riffer::Tools::Runtime::Fibers.new(max_concurrency: 10)
end
```

Fibers use cooperative scheduling — they yield control at I/O boundaries (network calls, file reads, sleep). CPU-bound tools will not benefit from the fibers runtime. Be mindful of fiber-local state (`Fiber.[]`) and note that `Thread.current[]` values are shared across all fibers in the same thread.

### Custom Runtimes

Create a custom runtime by subclassing `Riffer::Tools::Runtime` and overriding the private `dispatch_tool_call` method:

```ruby
class HttpToolRuntime < Riffer::Tools::Runtime
  private

  def dispatch_tool_call(tool_call, tools:, context:, assistant_message: nil)
    # Dispatch tool execution to an external service
    response = HttpClient.post("/tools/execute", {
      name: tool_call.name,
      arguments: tool_call.arguments
    })
    Riffer::Tools::Response.text(response.body)
  rescue HttpClient::Error => e
    Riffer::Tools::Response.error("Tool service unavailable: #{e.message}", type: :execution_error)
  end
end
```

Anything that escapes `dispatch_tool_call` propagates out of the run — rescue whatever your transport can raise and return an error response. The base class handles only an unknown tool name and malformed argument JSON.

### Around-Call Hook

Each tool call is wrapped by the `around_tool_call` method, which yields by default. Override it in a subclass to add instrumentation, logging, or other cross-cutting concerns:

```ruby
class InstrumentedRuntime < Riffer::Tools::Runtime::Inline
  private

  def around_tool_call(tool_call, context:, assistant_message: nil)
    start = Time.now
    result = yield
    duration = Time.now - start
    Rails.logger.info("Tool #{tool_call.name} took #{duration}s")
    result
  end
end
```

Subclasses inherit the hook and can override it further.

The `assistant_message:` kwarg is the `Riffer::Messages::Assistant` that produced the tool calls (the same object the agent appends to message history). It is `nil` when the runtime is invoked outside an agent loop. Use it when your hook or dispatcher needs context that lives on the assistant turn — for example, the accompanying assistant text, the model's reasoning content, or the full set of sibling tool calls from the same turn. The kwarg is **not** forwarded to `Tool#call`; tools that need it must read it via a custom `dispatch_tool_call` override.

> **Note:** Custom runtimes that override `around_tool_call` or `dispatch_tool_call` must accept the `assistant_message:` kwarg (or `**kwargs`). Older overrides that omit it will raise `ArgumentError: unknown keyword: :assistant_message`.
