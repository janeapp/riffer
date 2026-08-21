# Riffer

The all-in-one Ruby framework for building AI-powered applications and agents.

[![Gem Version](https://badge.fury.io/rb/riffer.svg)](https://badge.fury.io/rb/riffer)

## Requirements

- Ruby 3.3, 3.4, or 4.0

## Installation

Install the released gem:

```bash
gem install riffer
```

Or add to your application's Gemfile:

```ruby
gem 'riffer'
```

## Quick Start

```ruby
require 'riffer'

# Configure your provider
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end

# Define an agent
class EchoAgent < Riffer::Agent
  model 'openai/gpt-5-mini'
  instructions 'You are an assistant that repeats what the user says.'
end

# Use the agent
agent = EchoAgent.new
puts agent.generate('Hello world')
```

## Documentation

Comprehensive guides live at [riffer.ai](https://riffer.ai):

- [Overview](https://riffer.ai/guides/overview/) - Core concepts and architecture
- [Getting Started](https://riffer.ai/guides/getting-started/) - Installation and first steps
- [Agents](https://riffer.ai/guides/agents/) - Defining and configuring agents
- [Agent Lifecycle](https://riffer.ai/guides/agent-lifecycle/) - Generate, stream, and responses
- [Agent Loop](https://riffer.ai/guides/agent-loop/) - Tool execution flow and stopping
- [Tools](https://riffer.ai/guides/tools/) - Creating tools for agents
- [Advanced Tools](https://riffer.ai/guides/advanced-tools/) - Timeouts, runtime, and registration
- [Messages](https://riffer.ai/guides/messages/) - Message types and formats
- [Stream Events](https://riffer.ai/guides/stream-events/) - Streaming responses
- [Configuration](https://riffer.ai/guides/configuration/) - Framework configuration
- [Evals](https://riffer.ai/guides/evals/) - Evaluating agent quality
- [Guardrails](https://riffer.ai/guides/guardrails/) - Input/output validation
- [Skills](https://riffer.ai/guides/skills/) - Packaged agent capabilities
- [MCP](https://riffer.ai/guides/mcp/) - Integrating third-party MCP servers
- [Serialization](https://riffer.ai/guides/serialization/) - Persisting and transferring agent definitions
- [Tracing](https://riffer.ai/guides/tracing/) - OpenTelemetry span contract and host wiring
- [Providers](https://riffer.ai/guides/providers/overview/) - LLM provider adapters

The guide sources are in the [docs](docs/) directory.

### API Reference

The full API reference is published at [riffer.ai/api](https://riffer.ai/api/). Preview the site locally with:

```bash
bin/rake docs:serve
```

Then open <http://localhost:8000>. The site uses root-absolute paths, so it must be served over HTTP — opening `_site/index.html` via `file://` won't work.

## Development

After checking out the repo, run:

```bash
bin/setup
```

Common workflows are wrapped in `bin/`. Each is a thin `exec bundle exec …` script — use them
instead of typing `bundle exec` yourself:

| Command         | Description                                |
| --------------- | ------------------------------------------ |
| `bin/rake`      | Default task: test + rubocop + steep:check |
| `bin/test`      | Run tests                                  |
| `bin/lint`      | Check code style (pass `-a` to auto-fix)   |
| `bin/typecheck` | Run Steep type checker                     |
| `bin/rbs`       | Generate RBS type signatures               |
| `bin/rbs-watch` | Watch and regenerate RBS files             |
| `bin/docs`      | Build the docs site + API reference        |
| `bin/build`     | Build the gem package                      |
| `bin/console`   | Interactive console                        |

`bin/rake <task>` is the escape hatch for any rake task without a named wrapper (e.g.
`bin/rake test:slow`, `bin/rake release`).

### Recording VCR Cassettes

Integration tests use [VCR](https://github.com/vcr/vcr) to record and replay HTTP interactions. When adding new tests that hit provider APIs, you need to record cassettes with real API keys.

Create a `.env` file in the project root (it is gitignored):

```bash
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
AWS_BEDROCK_API_TOKEN=...
```

The test helper loads this file automatically via `dotenv`. Then run the specific tests that need new cassettes:

```bash
bundle exec ruby -Itest test/riffer/providers/open_ai_test.rb
bundle exec ruby -Itest test/riffer/providers/anthropic_test.rb
bundle exec ruby -Itest test/riffer/providers/amazon_bedrock_test.rb
```

VCR records the HTTP interactions to `test/fixtures/vcr_cassettes/` on the first run. Subsequent runs replay from the cassettes without hitting the API. API keys are automatically filtered from recorded cassettes.

## Contributing

1. Fork the repository and create your branch: `git checkout -b feature/foo`
2. Run tests and linters locally: `bin/rake`
3. Submit a pull request with a clear description of the change

Please follow the [Code of Conduct](https://github.com/janeapp/riffer/blob/main/CODE_OF_CONDUCT.md).

## Changelog

All notable changes to this project are documented in `CHANGELOG.md`.

## License

Licensed under the MIT License. See `LICENSE.txt` for details.
