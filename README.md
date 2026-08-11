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

For comprehensive documentation, see the [docs](docs/) directory:

- [Overview](docs/01_OVERVIEW.md) - Core concepts and architecture
- [Getting Started](docs/02_GETTING_STARTED.md) - Installation and first steps
- [Agents](docs/03_AGENTS.md) - Defining and configuring agents
- [Agent Lifecycle](docs/04_AGENT_LIFECYCLE.md) - Generate, stream, and responses
- [Agent Loop](docs/05_AGENT_LOOP.md) - Tool execution flow and stopping
- [Tools](docs/06_TOOLS.md) - Creating tools for agents
- [Advanced Tools](docs/07_TOOL_ADVANCED.md) - Timeouts, runtime, and registration
- [Messages](docs/08_MESSAGES.md) - Message types and formats
- [Stream Events](docs/09_STREAM_EVENTS.md) - Streaming responses
- [Configuration](docs/10_CONFIGURATION.md) - Framework configuration
- [Evals](docs/11_EVALS.md) - Evaluating agent quality
- [Guardrails](docs/12_GUARDRAILS.md) - Input/output validation
- [Skills](docs/13_SKILLS.md) - Packaged agent capabilities
- [MCP](docs/14_MCP.md) - Integrating third-party MCP servers
- [Serialization](docs/15_SERIALIZATION.md) - Persisting and transferring agent definitions
- [Tracing](docs/16_TRACING.md) - OpenTelemetry span contract and host wiring
- [Providers](docs/providers/01_PROVIDERS.md) - LLM provider adapters

### API Reference

Generate the full API documentation with:

```bash
bin/docs
```

Then open `doc/index.html` in your browser.

## Development

After checking out the repo, run:

```bash
bin/setup
```

Common workflows are wrapped in `bin/`. Each is a thin `exec bundle exec …` script — use them
instead of typing `bundle exec` yourself:

| Command         | Description                                 |
| --------------- | ------------------------------------------- |
| `bin/rake`      | Default task: test + rubocop + steep:check  |
| `bin/test`      | Run tests                                   |
| `bin/lint`      | Check code style (pass `-a` to auto-fix)    |
| `bin/typecheck` | Run Steep type checker                      |
| `bin/rbs`       | Generate RBS type signatures                |
| `bin/rbs-watch` | Watch and regenerate RBS files              |
| `bin/docs`      | Build RDoc HTML                             |
| `bin/build`     | Build the gem package                       |
| `bin/console`   | Interactive console                         |

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

## Maintainers

- Jake Bottrall - https://github.com/bottrall
