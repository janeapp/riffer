# Skills

Skills are packaged AI agent capabilities per the [Agent Skills spec](https://agentskills.io/). Each skill is a directory containing a `SKILL.md` file with YAML frontmatter and Markdown instructions. The framework discovers skills through a pluggable backend, injects a compact catalog into the system prompt (~50 tokens/skill), and provides a tool for the LLM to activate skills on demand.

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

Additional frontmatter keys are passed through as metadata.

## Configuring an Agent

Use the `skills` block DSL to configure skills:

```ruby
class MyAgent < Riffer::Agent
  model "openai/gpt-4o"
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

The adapter controls how the skill catalog is rendered in the system prompt and which tool the LLM calls to activate a skill. The adapter is auto-selected by provider (Markdown for most, XML for Anthropic). Override with:

```ruby
skills do
  backend Riffer::Skills::FilesystemBackend.new(".skills")
  adapter Riffer::Skills::XmlAdapter
end
```

### Activated Skills

Load skill instructions into the system prompt at startup (no tool call needed):

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
3. **Activation** — When the LLM matches a task to a skill, it calls the `skill_activate` tool with the skill name. The tool returns the full SKILL.md body.
4. **Execution** — The LLM follows the skill's instructions to complete the task.

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

Subclass `Riffer::Skills::Adapter` to customize how the skill catalog is rendered and which tool the LLM uses to activate skills:

```ruby
class CustomAdapter < Riffer::Skills::Adapter
  def render_catalog(skills)
    # Return String (skill catalog for the system prompt)
    # Use `activate_tool.name` to reference the activation tool
  end

  def activate_tool
    # Return a Riffer::Tool subclass
    # Defaults to Riffer::Skills::ActivateTool
    Riffer::Skills::ActivateTool
  end
end
```

The built-in adapters are `Riffer::Skills::MarkdownAdapter` (default) and `Riffer::Skills::XmlAdapter` (used by Anthropic).

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
