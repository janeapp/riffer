# Architecture

## Core Components

### Agent (`lib/riffer/agent.rb`)

Base class for AI agents. Subclass and use DSL methods `model`, `instructions`, `structured_output`, and `skills` to configure. Orchestrates message flow, LLM calls, tool execution, structured output parsing, and skill activation via a generate/stream loop.

Class-level DSL settings live on a per-class `Riffer::Agent::Config` object accessible via `MyAgent.config`. DSL methods read and mutate this Config in place. Instances read from `@config`, which defaults to `self.class.config` but can be replaced via `Agent.new(config: ...)`.

```ruby
class EchoAgent < Riffer::Agent
  model 'openai/gpt-5-mini' # provider/model
  instructions 'You are an assistant that repeats what the user says.'
end

agent = EchoAgent.new
puts agent.generate('Hello world')
```

`instructions` also accepts a Proc for dynamic instructions resolved at generate time. The Proc receives the `context` hash:

```ruby
class PersonalAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions ->(context) { "You are assisting #{context[:name]}" }
end

PersonalAgent.generate('Hello!', context: { name: 'Jane' })
```

### Providers (`lib/riffer/providers/`)

Adapters for LLM APIs. The base class uses a template-method pattern — `generate_text` and `stream_text` orchestrate the flow, delegating to five hook methods each provider implements:

- `build_request_params(messages, model, options)` — convert messages, tools, and options into SDK params
- `execute_generate(params)` — call the SDK and return the raw response
- `execute_stream(params, yielder)` — call the streaming SDK, mapping events to the yielder
- `extract_token_usage(response)` — pull token counts from the SDK response
- `extract_content(response)` — extract text content from the SDK response
- `extract_tool_calls(response)` — extract tool calls from the SDK response

Providers are registered in `Riffer::Providers::Repository::REPO` with identifiers (e.g., `openai`, `amazon_bedrock`).

Each provider declares a preferred skill adapter via `self.skills_adapter(model = nil)`. Default is Markdown; Anthropic returns XML; Amazon Bedrock returns XML when the model identifier matches an Anthropic model (e.g. `anthropic.claude-…` or `us.anthropic.claude-…`); Mock returns XML when the model name contains `claude`. The agent passes the resolved model identifier so proxy providers (Bedrock, Mock) can pick the right adapter without per-agent overrides.

### Skills (`lib/riffer/skills/`)

Support for the [Agent Skills spec](https://agentskills.io/). Skills are packaged as directories containing `SKILL.md` files with YAML frontmatter. The framework discovers skills through a pluggable backend, injects metadata into the system prompt, and provides a tool (`skill_activate`) for the LLM to load full skill instructions on demand.

- `Config` - DSL configuration object (`backend`, `adapter`, `activate`)
- `Backend` - base class interface (`list_skills`, `read_skill`)
- `FilesystemBackend` - built-in filesystem scanner
- `Frontmatter` - parsed YAML frontmatter value object with `.parse(raw)` class method
- `Context` - coordinates discovery, activation, caching, and prompt rendering for a generation cycle
- `Adapter` - base class for skill adapters (`render_catalog`, `activate_tool`)
- `MarkdownAdapter` - default Markdown skill adapter
- `XmlAdapter` - XML skill adapter for Anthropic/Claude
- `ActivateTool` - default tool the LLM calls to activate a skill

### Messages (`lib/riffer/messages/`)

Typed message objects that extend `Riffer::Messages::Base`:

- `System` - system instructions
- `User` - user input (supports file attachments via `Riffer::Messages::FilePart`)
- `Assistant` - AI responses
- `Tool` - tool execution results

`Riffer::Messages::FilePart` represents file attachments (images and documents) that can be included with User messages. Supports file paths, URLs, and raw base64 data.

The `Converter` module handles hash-to-object conversion, including file hash-to-`FilePart` conversion.

### StreamEvents (`lib/riffer/stream_events/`)

Structured events for streaming responses:

- `TextDelta` - incremental text chunks
- `TextDone` - completion signals
- `ReasoningDelta` - reasoning process chunks
- `ReasoningDone` - reasoning completion
- `WebSearchStatus` - web search status updates
- `WebSearchDone` - web search completion with query and sources
- `Interrupt` - callback interrupted the agent loop

### Per-Call State Reset

Each call to `generate` or `stream` resets `context`, tools, tool runtime, model, skills state, and the interrupted flag via `prepare_run`. Only the message history and cumulative `token_usage` persist across calls. This means `context:` must be passed on every call.

### Stopping the Loop Early

Two mechanisms can stop the agent loop before the LLM finishes naturally:

**Guardrail tripwires** — declarative policy enforcement registered at class level. A `:before` guardrail can block the request before the LLM is called; an `:after` guardrail can block the response. Tripwires are not resumable — the caller must change the input and start over. `Response#blocked?` returns `true`.

**Callback interrupts** — imperative flow control via `on_message` callbacks. Use `throw :riffer_interrupt` to pause the loop at any point. `Response#interrupted?` returns `true`. In streaming, yields an `Interrupt` event.

### Resuming After an Interrupt

Two resume paths:

- **In-memory** — call `generate` or `stream` again with a string on the same agent instance. The message history is preserved and the new user message is appended.
- **Cross-process** — pass persisted messages as an array to a new agent instance. Array input uses messages as-is (no system message prepend). Passing an array to an agent that already has messages raises `Riffer::ArgumentError`.

```ruby
agent.generate('Continue')              # in-memory resume
MyAgent.new.stream(persisted_messages)  # cross-process resume
```

On resume, `execute_pending_tool_calls` detects tool calls from the last assistant message that lack corresponding tool result messages and executes them before entering the LLM loop. This handles the case where an interrupt fired mid-way through tool execution.

### Runner (`lib/riffer/runner.rb`)

Concurrency primitive for batch execution. Subclasses implement `#map(items, context: nil, &block)` to control how items are processed. The `context` keyword carries the agent's context hash, enabling runners that need it for job serialization or routing.

Built-in runners:

- `Sequential` — processes items in the current thread via `Array#map`
- `Threaded` — processes items concurrently using a thread pool with configurable `max_concurrency`

```ruby
runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
runner.map(items, context: ctx) { |item| process(item) }
```

### Tools::Runtime (`lib/riffer/tools/runtime.rb`)

Composes with a Runner to execute tool calls. Provides `#execute` as the public entry point and `#around_tool_call` as a hook for instrumentation. Passes the agent context through to the runner.

Built-in runtimes:

- `Inline` — uses `Runner::Sequential` (default)
- `Threaded` — uses `Runner::Threaded`

Context flow: `Agent#execute_tool_calls` → `Tools::Runtime#execute(tool_calls, tools:, context:)` → `Runner#map(tool_calls, context:) { dispatch }` → `Tool#call(context:, **args)`

### MCP Integration (`lib/riffer/mcp/`)

Register third-party MCP servers globally; agents opt-in by tag via `use_mcp`. Tags are application-defined (manifests may list several; any overlap with `use_mcp` opts in—see `docs/MCP.md`).

```ruby
Riffer::Mcp.register(
  name: "github",
  tags: [:github],
  endpoint: "https://mcp.github.com",
  discovery_headers: -> { {"Authorization" => "Bearer #{ENV['GITHUB_TOKEN']}"} }
)

# Optional: per-run tools/call headers (see docs/MCP.md)
Riffer.configure { |c| c.mcp.credentials = ->(manifest:, matched_tags:, context:) { ... } }

class ResearchAgent < Riffer::Agent
  model "openai/gpt-5-mini"
  use_mcp :github                      # picks up any :github-tagged registration
  use_mcp :search, on_pending: :wait   # per-call override
end
```

Key types: `Manifest` (`discovery_headers`, optional `credentials_scope` hint), `Registry` (thread-safe store), `Registration` (spawns discovery thread → `ToolFactory`), `Client` (wraps `mcp` gem), `AuthenticatedTool` (wraps MCP tools when `credentials` proc is set).

**on_pending strategies** (global default `:ignore`): `:ignore` skips the server; `:wait` blocks until ready, re-raises failed discovery immediately, or times out; `:raise` re-raises failed discovery or `NotReadyError` while still pending.

## Key Patterns

- Model config accepts a `provider/model` string (e.g., `openai/gpt-5-mini`) or a Proc/lambda that returns one
- Configuration via `Riffer.configure { |c| c.openai.api_key = "..." }`
- Providers use `depends_on` helper for runtime dependency checking
- Zeitwerk for autoloading - file structure must match module/class names

## Project Structure

```
examples/
  evaluators/            # Reference evaluator implementations (copy-paste)
  guardrails/            # Reference guardrail implementations (copy-paste)
lib/
  riffer.rb              # Main entry point, uses Zeitwerk for autoloading
  riffer/
    version.rb           # VERSION constant
    config.rb            # Configuration class
    agent.rb             # Agent class
    agent/
      config.rb          # Per-class DSL configuration value object
      session.rb         # Conversation handle (message array + invariants)
      session/
        repair.rb        # tool_use ↔ tool_result invariant repair
      structured_output.rb # Structured output schema wrapper
      structured_output/
        result.rb        # Parse/validation result object
    messages.rb          # Messages namespace/module
    providers.rb         # Providers namespace/module
    params.rb            # Parameter collection with DSL and validation
    params/
      param.rb           # Single parameter definition (shared by tools and structured output)
      boolean.rb         # Boolean sentinel type
    stream_events.rb     # Stream events namespace/module
    skills.rb            # Skills namespace/module
    skills/
      config.rb          # DSL configuration object
      adapter.rb         # Adapter base class (render_catalog, activate_tool)
      markdown_adapter.rb # Default Markdown skill adapter
      xml_adapter.rb     # XML skill adapter for Anthropic/Claude
      backend.rb         # Backend base class (interface)
      filesystem_backend.rb # Built-in filesystem backend
      frontmatter.rb     # Parsed YAML frontmatter value object with .parse
      context.rb         # Skills context for a generation cycle
      activate_tool.rb   # Default skill_activate tool
    helpers/
      class_name_converter.rb  # Class name conversion utilities
      dependencies.rb          # Dependency management
    messages/
      base.rb            # Base message class
      assistant.rb       # Assistant message
      converter.rb       # Message converter
      system.rb          # System message
      user.rb            # User message
      tool.rb            # Tool message
      file_part.rb       # File attachment (images and documents)
    providers/
      base.rb            # Base provider class
      open_ai.rb         # OpenAI provider
      amazon_bedrock.rb  # Amazon Bedrock provider
      anthropic.rb       # Anthropic provider
      repository.rb      # Provider registry
      mock.rb            # Mock provider
    stream_events/
      base.rb            # Base stream event
      interrupt.rb       # Interrupt event
      text_delta.rb      # Text delta event
      text_done.rb       # Text done event
      reasoning_delta.rb # Reasoning delta event
      reasoning_done.rb  # Reasoning done event
      web_search_status.rb # Web search status event
      web_search_done.rb   # Web search done event
    mcp.rb               # MCP public API + error classes
    mcp/
      manifest.rb        # Server config value object
      registry.rb        # Thread-safe global store
      registration.rb    # Per-server state + discovery thread
      client.rb          # Thin mcp gem wrapper
      authenticated_tool.rb  # Wraps MCP tools when credentials proc is configured
      tool_factory.rb    # Generates Riffer::Tool subclasses from MCP tools
test/
  test_helper.rb         # Minitest configuration with VCR
  riffer_test.rb         # Main module tests
  riffer/
    [feature]_test.rb    # Feature tests mirror lib/riffer/ structure
```

## Configuration Example

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end
```

## Streaming Example

```ruby
agent = EchoAgent.new
agent.stream('Tell me a story').each do |event|
  print event.content
end
```
