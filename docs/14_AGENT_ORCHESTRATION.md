# Agent Orchestration

Agents can delegate tasks to specialized subagents. Register subagents with `uses_agents` and the LLM decides when to delegate based on each subagent's description.

## When to Use Subagents

Use subagents when a task naturally decomposes into distinct specialties — for example, one agent researches while another writes. If a single agent with tools can handle the task, prefer that simpler setup. Subagents add value when each subtask benefits from its own instructions, model, or tool set.

## Defining Subagents

Subagents are regular agents with a `description` (required — the LLM uses it to decide when to delegate):

```ruby
class ResearchAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  description 'Researches topics and returns detailed summaries'
  instructions 'You are a research specialist. Provide thorough, cited research.'
end

class WriterAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  description 'Writes polished content from research notes'
  instructions 'You are a professional writer.'
end
```

## Delegating to Subagents

Register subagents with `uses_agents`:

```ruby
class MaestroAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You coordinate research and writing tasks.'
  uses_agents [ResearchAgent, WriterAgent]
end

response = MaestroAgent.generate('Write an article about Ruby concurrency')
```

Your agent can also use regular tools alongside subagents:

```ruby
class MaestroAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_tools [WebSearchTool]
  uses_agents [ResearchAgent, WriterAgent]
end
```

Subagents can also be resolved dynamically with a lambda:

```ruby
# Dynamic resolution with a lambda
class MaestroAgent < Riffer::Agent
  model 'openai/gpt-5-mini'

  uses_agents ->(context) {
    agents = [ResearchAgent]
    agents << WriterAgent if context&.dig(:enable_writing)
    agents
  }
end
```

## How It Works

Under the hood, each subagent is exposed to the LLM as a tool with an `agent__` prefix (e.g., `agent__research_agent`). Each tool accepts a single `message` parameter — what your agent tells the subagent. When the LLM returns agent tool calls, they are partitioned from regular tool calls and dispatched to the `AgentRuntime` instead of the `ToolRuntime`.

## Context Propagation

The calling agent's `context` is passed through to subagents automatically:

```ruby
response = MaestroAgent.generate(
  'Research Ruby GC',
  context: {user_id: 123, preferences: {depth: :detailed}}
)
# ResearchAgent receives the same context
```

## Agent Runtime (Experimental)

> **Warning:** This feature is experimental and may be removed or changed without warning in a future release.

By default, subagent calls are executed sequentially using `Riffer::AgentRuntime::Inline`. Use `Riffer::AgentRuntime::Threaded` for concurrent execution:

```ruby
class MaestroAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  uses_agents [ResearchAgent, WriterAgent]
  agent_runtime Riffer::AgentRuntime::Threaded
end
```

| Runtime                          | Description                                     |
| -------------------------------- | ----------------------------------------------- |
| `Riffer::AgentRuntime::Inline`   | Executes agent calls sequentially (default)     |
| `Riffer::AgentRuntime::Threaded` | Executes agent calls concurrently using threads |

The threaded runtime accepts a `max_concurrency` option (default: 5):

```ruby
agent_runtime Riffer::AgentRuntime::Threaded.new(max_concurrency: 3)
```

Dynamic resolution with a lambda is also supported:

```ruby
agent_runtime ->(context) {
  context&.dig(:parallel) ? Riffer::AgentRuntime::Threaded.new : Riffer::AgentRuntime::Inline.new
}
```

### Threaded Runtime Considerations

When using `Riffer::AgentRuntime::Threaded`, each subagent runs in its own thread. Be mindful of thread-local state — for example, `ActiveRecord::Base.connection`, `RequestStore`, or any `Thread.current[]` values may not be available or may behave differently across threads. Ensure your subagents and their tools are thread-safe.

### Global Configuration

Set a default agent runtime for all agents:

```ruby
Riffer.configure do |config|
  config.agent_runtime = Riffer::AgentRuntime::Threaded
end
```

Per-agent configuration overrides the global default. See [Configuration](10_CONFIGURATION.md#agent-runtime-experimental) for details.

## Custom Runtimes

Create a custom runtime by subclassing `Riffer::AgentRuntime` and overriding the private `dispatch_agent_call` method:

```ruby
class RemoteAgentRuntime < Riffer::AgentRuntime
  private

  def dispatch_agent_call(tool_call, agents:, context:)
    response = HttpClient.post("/agents/execute", {
      name: tool_call.name,
      arguments: tool_call.arguments
    })
    Riffer::Tools::Response.text(response.body)
  rescue RuntimeError => e
    Riffer::Tools::Response.error("Error executing agent: #{e.message}", type: :execution_error)
  end
end
```

### Around-Call Hook

Each agent call is wrapped by the `around_agent_call` method, which yields by default. Override it in a subclass to add instrumentation, logging, or other cross-cutting concerns:

```ruby
class InstrumentedAgentRuntime < Riffer::AgentRuntime::Inline
  private

  def around_agent_call(tool_call, context:)
    start = Time.now
    result = yield
    Rails.logger.info("Agent #{tool_call.name} took #{Time.now - start}s")
    result
  end
end
```

Subclasses inherit the hook and can override it further.

## Error Handling

Subagent execution errors are handled gracefully and returned to the calling agent:

- **Blocked** — If a subagent's guardrail fires, the calling agent receives an error: `"Agent was blocked: <reason>"`
- **Interrupted** — If a subagent hits its `max_steps` limit, the calling agent receives the partial content: `"Agent was interrupted: <content>"`
- **RuntimeError** — Exceptions are caught and returned as error responses

## Constraints

- An agent cannot use itself as a subagent (raises `Riffer::ArgumentError`)
- Circular agent delegation is detected at runtime — if Agent A delegates to Agent B which delegates back to Agent A, the cycle is caught and returned as an error response to the calling agent (rather than causing a stack overflow)
- Subagent tool names must not conflict with regular tool names (raises `Riffer::ArgumentError`)
- Subagents must have a `description` (raises `Riffer::ArgumentError`)
