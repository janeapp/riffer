# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Riffer is a Ruby gem framework for building AI-powered applications and agents. It uses Zeitwerk for autoloading.

## Commands

```bash
# Install dependencies
bin/setup

# Run tests
bundle exec rake test

# Run a single test file
bundle exec ruby -Ilib:test test/riffer/agent_test.rb

# Run a specific test by name
bundle exec ruby -Ilib:test test/riffer/agent_test.rb --name "test_something"

# Check code style
bundle exec rake standard

# Auto-fix style issues
bundle exec rake standard:fix

# Run both tests and linting (default task)
bundle exec rake

# Interactive console
bin/console

# Generate documentation
bundle exec rake docs
```

## Architecture

### Core Components

- **Agent** (`lib/riffer/agent.rb`): Base class for AI agents. Subclass and use DSL methods `model` and `instructions` to configure. Orchestrates message flow, LLM calls, and tool execution via a generate/stream loop.

- **Providers** (`lib/riffer/providers/`): Adapters for LLM APIs. Each provider extends `Riffer::Providers::Base` and implements `perform_generate_text` and `perform_stream_text`. Registered in `Repository` with identifier (e.g., `openai`).

- **Messages** (`lib/riffer/messages/`): Typed message objects (`System`, `User`, `Assistant`, `Tool`). All extend `Base`. The `Converter` module handles hash-to-object conversion.

- **StreamEvents** (`lib/riffer/stream_events/`): Structured events for streaming (`TextDelta`, `TextDone`).

### Key Patterns

- Model strings use `provider/model` format (e.g., `openai/gpt-4`)
- Configuration via `Riffer.configure { |c| c.openai.api_key = "..." }`
- Providers use `depends_on` helper for runtime dependency checking
- Tests use VCR cassettes in `test/fixtures/vcr_cassettes/`

### Adding a New Provider

1. Create `lib/riffer/providers/your_provider.rb` extending `Riffer::Providers::Base`
2. Implement `perform_generate_text(messages, model:)` returning `Riffer::Messages::Assistant`
3. Implement `perform_stream_text(messages, model:)` returning an `Enumerator` yielding stream events
4. Register in `Riffer::Providers::Repository::REPO`
5. Add provider config to `Riffer::Config` if needed

## Code Style

- Ruby 3.2+ required
- All files must have `# frozen_string_literal: true`
- StandardRB for formatting (double quotes, 2-space indent)
- Minitest with spec DSL for tests
- YARD-style documentation for public APIs
