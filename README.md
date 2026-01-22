# Riffer

The all-in-one Ruby framework for building AI-powered applications and agents.

[![Gem Version](https://badge.fury.io/rb/riffer.svg)](https://badge.fury.io/rb/riffer)

## Requirements

- Ruby 3.2 or later

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
  model 'openai/gpt-4o'
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
- [Agents](docs/03_AGENTS.md) - Building AI agents
- [Tools](docs/04_TOOLS.md) - Creating tools for agents
- [Messages](docs/05_MESSAGES.md) - Message types and formats
- [Stream Events](docs/06_STREAM_EVENTS.md) - Streaming responses
- [Configuration](docs/07_CONFIGURATION.md) - Framework configuration
- [Providers](docs_providers/01_PROVIDERS.md) - LLM provider adapters

### API Reference

Generate the full API documentation with:

```bash
bundle exec rake docs
```

Then open `doc/index.html` in your browser.

## Development

After checking out the repo, run:

```bash
bin/setup
```

Run the test suite:

```bash
bundle exec rake test
```

Check and fix code style:

```bash
bundle exec rake standard
bundle exec rake standard:fix
```

Run the interactive console:

```bash
bin/console
```

## Contributing

1. Fork the repository and create your branch: `git checkout -b feature/foo`
2. Run tests and linters locally: `bundle exec rake`
3. Submit a pull request with a clear description of the change

Please follow the [Code of Conduct](https://github.com/janeapp/riffer/blob/main/CODE_OF_CONDUCT.md).

## Changelog

All notable changes to this project are documented in `CHANGELOG.md`.

## License

Licensed under the MIT License. See `LICENSE.txt` for details.

## Maintainers

- Jake Bottrall - https://github.com/bottrall
