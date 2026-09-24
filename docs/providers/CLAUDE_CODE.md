# Claude Code Provider

The Claude Code provider shells out to the installed `claude` CLI, so calls run under the operator's existing Claude Code login instead of an API key.

## Prerequisites

Install the [Claude Code CLI](https://docs.claude.com/en/docs/claude-code) and log in:

```bash
claude auth login
```

The provider resolves `claude` from `PATH` by default.

## Configuration

No credentials are required for the default `:subscription` auth mode — the CLI reuses its own OAuth login:

```ruby
Riffer.configure do |config|
  config.claude_code.default_model = "sonnet"
end
```

To use an API key, Bedrock, or Vertex instead, set `auth: :api_key`, which leaves the environment untouched:

```ruby
Riffer.configure do |config|
  config.claude_code.auth = :api_key
end
```

Providers take no constructor arguments; every setting is read from `Riffer.config.claude_code`.

## Options

| Option                | Default                | Description                                                                                                                     |
| ---------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `binary`                | `"claude"`               | Executable name or absolute path. Resolved via `PATH`; raises if missing or not executable.                                      |
| `auth`                  | `:subscription`         | `:subscription` (CLI OAuth login) or `:api_key` (leaves the environment untouched for API key/Bedrock/Vertex).                    |
| `default_model`         | `nil`                    | Model used by direct `generate_text`/`stream_text` calls that pass no `model:`. Agents always pass a model, so this has no effect on them. |
| `cwd`                   | a private per-instance directory | Working directory for the CLI process. The default is created fresh per provider instance; pointing it at a directory other users can write to lets a planted `.claude/settings.json` run hooks under this process. |
| `timeout`               | `120`                    | Wall-clock timeout in seconds; the whole process group is killed on expiry.                                                        |
| `scrub_env`             | see below                | Env vars removed from the child process under `:subscription` auth, so a stray key can't silently get billed.                     |
| `setting_sources`       | `"project"`              | Passed to `--setting-sources`.                                                                                                     |
| `system_prompt_mode`    | `:append`                | `:append` (`--append-system-prompt`) or `:replace` (`--system-prompt`).                                                            |
| `session_persistence`   | `true`                   | Enables multi-turn conversations via session resume. Set `false` for stateless single-turn calls.                                 |
| `allowed_tools`         | `[]`                     | Tool names passed to `--allowedTools` and `--tools`. Empty by default, which disables the CLI's built-in tools and grants no permissions. |
| `client`                | `Riffer::Providers::ClaudeCode::Client.new` | Command-runner override — anything responding to `#call`/`#stream`. See [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients). |

`scrub_env` defaults to `Riffer::Providers::ClaudeCode::DEFAULT_SCRUB_ENV`: every env var that can route the CLI to a different backend or credential (`ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, the `ANTHROPIC_BEDROCK_*`/`ANTHROPIC_FOUNDRY_*`/`ANTHROPIC_VERTEX_*` vars, `AWS_BEARER_TOKEN_BEDROCK`, and the `CLAUDE_CODE_USE_*` backend switches).

## Supported Models

Use `claude_code/<model-id>`, or `claude_code/default` to defer to the CLI's own configured default model (omits `--model` entirely):

```ruby
model 'claude_code/sonnet'
model 'claude_code/default'
```

An unset model with no `default_model` configured raises.

## Example

```ruby
class AssistantAgent < Riffer::Agent
  model 'claude_code/sonnet'
  instructions 'You are a helpful assistant.'
end

agent = AssistantAgent.new
puts agent.generate("Explain quantum computing")
```

## Multi-Turn Conversations

Stateful conversations resume the CLI's own session (`--resume`), scoped to one provider instance. Only a conversation this provider produced can be resumed — fabricated or edited history, or resuming across a different provider instance, raises `Riffer::ArgumentError`. System-prompt drift across turns of the same session also raises.

Set `config.claude_code.session_persistence = false` for stateless single-turn calls; an assistant message in history then always raises.

## Streaming

```ruby
agent.stream("Tell me about Claude models").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::TextDone
    puts "\n[Complete]"
  when Riffer::StreamEvents::ReasoningDelta
    print "[Thinking] #{event.content}"
  when Riffer::StreamEvents::ReasoningDone
    puts "\n[Thinking Complete]"
  end
end
```

`TextDone` is emitted once, from the CLI's terminal result — not accumulated from deltas.

## Structured Output

Pass a `structured_output` schema; it is sent inline as `--json-schema`, and the result round-trips into `assistant.structured_output`:

```ruby
response = agent.generate("Extract the name and age", structured_output: PersonSchema)
response.structured_output
```

## Limitations

- No riffer tool calls — passing `tools:` raises `Riffer::ArgumentError`. Use an API provider, or allow the CLI's own built-in tools via `allowed_tools`.
- No file attachments on user messages.
- Tool-role messages always raise.
- The conversation must end in a user message.

## Errors

Raised as `Riffer::Error` (spawn/CLI/runtime failures, timeouts as `Riffer::TimeoutError`) or `Riffer::ArgumentError` (bad config or input contract violations).

## Direct Provider Usage

```ruby
provider = Riffer::Providers::ClaudeCode.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "sonnet"
)

puts response.content
```
