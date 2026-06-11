# Skills

Skills are packaged AI agent capabilities per the [Agent Skills spec](https://agentskills.io/). Each skill is a directory containing a `SKILL.md` file with YAML frontmatter and Markdown instructions. The framework discovers skills through a pluggable backend, injects a compact catalog into the system prompt (~50 tokens/skill), and supports both activation channels the spec describes: the LLM activates skills on demand through a tool, and your application injects skills the user asked for as conversation content (see [User-Triggered Activation](#user-triggered-activation)).

## Creating a Skill

Create a directory with a `SKILL.md` file:

```
.skills/
  code-review/
    SKILL.md
  data-analysis/
    SKILL.md
```

Each `SKILL.md` has YAML frontmatter and a Markdown body:

```markdown
---
name: code-review
description: Reviews code for quality, style, and potential issues.
---

You are a code review assistant.

Review the code for:

- Style issues
- Potential bugs
- Performance problems
```

**Required frontmatter fields:**

- `name` — lowercase alphanumeric with hyphens, 1-64 chars (must match directory name)
- `description` — 1-1024 chars, helps the LLM decide when to activate

**Optional frontmatter fields:**

- `disable-model-invocation` — when `true`, the skill is hidden from the catalog and the LLM cannot activate it via the `skill_activate` tool. It stays reachable through the programmatic `activate` config (see [Activated Skills](#activated-skills)) and through `activation_prompt` (see [User-Triggered Activation](#user-triggered-activation)), so you can inject it under your own logic instead of the model's. Only the literal value `true` disables invocation; any other value (or its absence) leaves the skill model-invocable.

Any other frontmatter keys are passed through as metadata.

## Configuring an Agent

Use the `skills` block DSL to configure skills:

```ruby
class MyAgent < Riffer::Agent
  model "openai/gpt-5-mini"
  instructions "You are a helpful assistant."
  skills do
    backend Riffer::Skills::FilesystemBackend.new(".skills")
  end
end
```

Multiple directories can be scanned (first-path-wins for duplicates):

```ruby
skills do
  backend Riffer::Skills::FilesystemBackend.new(".skills", "~/.riffer/skills")
end
```

### Dynamic Backend via Proc

```ruby
skills do
  backend ->(context) { tenant_backend(context[:tenant_id]) }
end
```

### Custom Adapter

The adapter controls how the skill catalog is rendered in the system prompt and which tool the LLM calls to activate a skill. The adapter is auto-selected by provider, with model-aware fallback for proxy providers — Markdown for most providers, XML for Anthropic, and XML for Anthropic models routed through Amazon Bedrock (e.g. `us.anthropic.claude-sonnet-4-6`). Override with:

```ruby
skills do
  backend Riffer::Skills::FilesystemBackend.new(".skills")
  adapter Riffer::Skills::XmlAdapter
end
```

### Activated Skills

Load skill instructions into the system prompt at startup (no tool call needed). Use this for skills that should govern the whole session — for skills the user requests mid-conversation, prefer [User-Triggered Activation](#user-triggered-activation), which keeps the system prompt (and its provider-side cache) stable:

```ruby
skills do
  backend Riffer::Skills::FilesystemBackend.new(".skills")
  activate ["code-review"]
end
```

Accepts a Proc for dynamic resolution:

```ruby
skills do
  backend Riffer::Skills::FilesystemBackend.new(".skills")
  activate ->(context) { context[:active_skills] || [] }
end
```

## How It Works

1. **Discovery** — At the start of `generate`/`stream`, the backend's `list_skills` returns frontmatter for all available skills.
2. **Catalog injection** — The adapter formats the catalog and appends it to the system prompt.
3. **Activation** — When the LLM matches a task to a skill, it calls the `skill_activate` tool with the skill name. The tool returns the full SKILL.md body wrapped in `<skill_content name="...">` tags.
4. **Execution** — The LLM follows the skill's instructions to complete the task.
5. **Deduplication** — Re-activating an already-active skill returns a short pointer ("already active") instead of the body again, so repeated activations don't fill the context with duplicate instructions. This applies whichever channel activated the skill first — tool call, `activation_prompt`, or the `activate` config.

Activation state lives in memory on the `Riffer::Skills::Context`, not in the session. When you rebuild an agent from a persisted session, the first re-activation of each skill returns the full body again (the conversation history still carries the earlier copy); deduplication resumes from there. If you prune skill content out of a session yourself, call `deactivate(name)` so the next activation returns the body instead of a pointer to content that no longer exists.

## User-Triggered Activation

When a user explicitly invokes a skill (a slash command, a button, a mention), don't wait for the model to discover it — inject the skill body into the conversation as a user message. `activation_prompt` returns the body wrapped for injection and records the activation, so a later model-side `skill_activate` call for the same skill gets the pointer instead of a duplicate body:

```ruby
agent = MyAgent.new
skills = agent.context.skills

# User typed: /code-review focus on security
if skills.activated?("code-review")
  agent.generate("The code-review skill was invoked again — its instructions are above. focus on security")
else
  agent.generate(skills.activation_prompt("code-review", args: "focus on security"))
end
```

`activation_prompt("code-review", args: "focus on security")` returns:

```
<skill_content name="code-review">
You are a code review assistant.
...
</skill_content>

focus on security
```

How a repeat invocation behaves is your choice — re-inject the full body (`activation_prompt` always returns it), or send a short reference as above. The check via `activated?` covers both channels, so a skill the model already activated through the tool counts too.

For reading a skill body **without** recording an activation — a UI preview, or delegating the skill to a subagent whose context is separate — use `read`:

```ruby
body = skills.read("code-review") # no activation recorded
```

## Custom Backends

Implement `Riffer::Skills::Backend` for non-filesystem storage:

```ruby
class DatabaseBackend < Riffer::Skills::Backend
  def list_skills
    # Return Array[Riffer::Skills::Frontmatter]
  end

  def read_skill(name)
    # Return String (skill body)
    # Raise Riffer::ArgumentError if not found
  end
end
```

## Custom Adapters

Subclass `Riffer::Skills::Adapter` to customize how the skill catalog is rendered in the system prompt:

```ruby
class CustomAdapter < Riffer::Skills::Adapter
  def render_catalog(skills)
    # Return String (skill catalog for the system prompt)
    # Use `skill_activate_tool.name` to reference the activation tool the LLM should call
  end
end
```

The activation tool is set on the adapter at construction (`Riffer::Skills::Adapter.new(skill_activate_tool: ...)`) and exposed via the `skill_activate_tool` reader. The agent wires this up automatically — custom adapters that override `initialize` must call `super`.

The built-in adapters are `Riffer::Skills::MarkdownAdapter` (default) and `Riffer::Skills::XmlAdapter` (used by Anthropic).

## Custom Activation Tool

The activation tool is global. Set it once via `Riffer.config.skills.default_activate_tool` to apply across all agents, or override per-agent inside the `skills` block.

The recommended approach is to subclass `Riffer::Skills::ActivateTool` so the identifier, description, params, and timeout are inherited — you only override the behavior you need to change:

```ruby
# Wrap the default behavior with telemetry
class InstrumentedActivateTool < Riffer::Skills::ActivateTool
  def call(context:, name:)
    Telemetry.measure("skill_activate", skill: name) { super }
  end
end

# Change what a re-activation returns (default: a short "already active" pointer)
class CustomPointerActivateTool < Riffer::Skills::ActivateTool
  private

  def already_active_message(name)
    "'#{name}' is loaded — scroll up for its instructions."
  end
end

# Return the full body on every activation (no deduplication)
class AlwaysFullBodyActivateTool < Riffer::Skills::ActivateTool
  def call(context:, name:)
    skills_context = context&.skills
    return error("Skills not configured") unless skills_context
    return error("Unknown skill: '#{name}'") unless skills_context.model_invocable?(name)

    text(skills_context.activation_prompt(name))
  rescue Riffer::ArgumentError => e
    error(e.message)
  end
end

# Global default
Riffer.config.skills.default_activate_tool = InstrumentedActivateTool

# Per-agent override
class MyAgent < Riffer::Agent
  skills do
    backend Riffer::Skills::FilesystemBackend.new(".skills")
    activate_tool InstrumentedActivateTool
  end
end
```

If you need a different parameter shape entirely, subclass `Riffer::Tool` directly and provide your own `identifier`, `description`, `params`, and `call`.

## Accessing Skills in Tools

The skills context (`Riffer::Skills::Context`) is available via `context[:skills]` during execution:

```ruby
class SkillSearchTool < Riffer::Tool
  identifier "skill_search"
  description "Searches available skills."

  params do
    required :query, String
  end

  def call(context:, query:)
    skills_context = context[:skills]  # Riffer::Skills::Context
    matches = skills_context.skills.values.select { |s| s.description.include?(query) }
    json(matches.map { |s| {name: s.name, description: s.description} })
  end
end
```
