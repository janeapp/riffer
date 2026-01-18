# AI Agent Development Guide

This guide provides comprehensive information for AI coding assistants working with the Riffer codebase.

## Project Overview

Riffer is a Ruby gem framework for building AI-powered applications and agents. It provides a complete toolkit for integrating artificial intelligence capabilities into Ruby projects with a minimal, well-documented core.

Key concepts:

- **Agents** – orchestrate messages, LLM calls, and tool execution (`Riffer::Agent`)
- **Providers** – adapters that implement text generation and streaming (`Riffer::Providers::*`)
- **Messages** – typed message objects for system, user, assistant, and tool messages (`Riffer::Messages::*`)
- **StreamEvents** – structured events for streaming (`Riffer::StreamEvents::*`)

## Architecture

### Core Components

#### Agent (`lib/riffer/agent.rb`)

Base class for AI agents. Subclass and use DSL methods `model` and `instructions` to configure. Orchestrates message flow, LLM calls, and tool execution via a generate/stream loop.

Example:

```ruby
class EchoAgent < Riffer::Agent
  model 'openai/gpt-5-mini' # provider/model
  instructions 'You are an assistant that repeats what the user says.'
end

agent = EchoAgent.new
puts agent.generate('Hello world')
```

#### Providers (`lib/riffer/providers/`)

Adapters for LLM APIs. Each provider extends `Riffer::Providers::Base` and implements:

- `perform_generate_text(messages, model:)` – returns `Riffer::Messages::Assistant`
- `perform_stream_text(messages, model:)` – returns an `Enumerator` yielding stream events

Providers are registered in `Riffer::Providers::Repository::REPO` with identifiers (e.g., `openai`, `amazon_bedrock`).

#### Messages (`lib/riffer/messages/`)

Typed message objects that extend `Riffer::Messages::Base`:

- `System` – system instructions
- `User` – user input
- `Assistant` – AI responses
- `Tool` – tool execution results

The `Converter` module handles hash-to-object conversion.

#### StreamEvents (`lib/riffer/stream_events/`)

Structured events for streaming responses:

- `TextDelta` – incremental text chunks
- `TextDone` – completion signals
- `ReasoningDelta` – reasoning process chunks
- `ReasoningDone` – reasoning completion

### Key Patterns

- Model strings use `provider/model` format (e.g., `openai/gpt-4`)
- Configuration via `Riffer.configure { |c| c.openai.api_key = "..." }`
- Providers use `depends_on` helper for runtime dependency checking
- Tests use VCR cassettes in `test/fixtures/vcr_cassettes/`
- Zeitwerk for autoloading – file structure must match module/class names

## Code Style & Standards

### Ruby Version

- Minimum Ruby version: 3.2.0
- Use modern Ruby 3.x features and syntax

### Code Formatting

- Use StandardRB for linting and formatting
- All Ruby files must include `# frozen_string_literal: true` at the top
- Follow StandardRB conventions (2-space indentation, double quotes for strings)
- Custom RuboCop rules are defined in `.standard.yml`

### Testing

- Use Minitest for all tests with the spec DSL
- Test files go in `test/` directory with `*_test.rb` suffix
- Tests must pass before committing
- Use Minitest assertions: `assert_equal`, `assert_instance_of`, `refute_nil`, etc.
- Prefer using `setup` and `teardown` methods for test setup/cleanup

#### Test Structure

```ruby
# frozen_string_literal: true

require "test_helper"

describe Riffer::Feature do
  describe "#method_name" do
    before do
      # setup code
    end

    it "does something expected" do
      result = Riffer::Feature.method_name(args)
      assert_equal expected, result
    end

    it "handles edge case" do
      result = Riffer::Feature.method_name(edge_case_args)
      assert_equal edge_case_expected, result
    end
  end
end
```

#### Test Coverage

- Test public APIs thoroughly
- Test edge cases and error conditions
- Mock external dependencies
- Keep tests fast and isolated
- Stick to the single assertion rule where possible

### Documentation

- Use YARD-style comments for public APIs
- Document parameters with `@param`
- Document return values with `@return`
- Document raised errors with `@raise`

### Comments

- Only add comments when the code is ambiguous or not semantically obvious
- Avoid stating what the code does if it's clear from reading the code itself
- Use comments to explain **why** something is done, not **what** is being done
- Comments should add value beyond what the code already expresses

### Error Handling

- Define custom errors as subclasses of `Riffer::Error`
- Use descriptive error messages
- Document errors that can be raised

## Project Structure

```
lib/
  riffer.rb              # Main entry point, uses Zeitwerk for autoloading
  riffer/
    version.rb           # VERSION constant
    config.rb            # Configuration class
    core.rb              # Core functionality
    agent.rb             # Agent class
    messages.rb          # Messages namespace/module
    providers.rb         # Providers namespace/module
    stream_events.rb     # Stream events namespace/module
    helpers/
      class_name_converter.rb  # Class name conversion utilities
      dependencies.rb          # Dependency management
      validations.rb           # Validation helpers
    messages/
      base.rb            # Base message class
      assistant.rb       # Assistant message
      converter.rb       # Message converter
      system.rb          # System message
      user.rb            # User message
      tool.rb            # Tool message
    providers/
      base.rb            # Base provider class
      open_ai.rb         # OpenAI provider
      amazon_bedrock.rb  # Amazon Bedrock provider
      repository.rb      # Provider registry
      test.rb            # Test provider
    stream_events/
      base.rb            # Base stream event
      text_delta.rb      # Text delta event
      text_done.rb       # Text done event
      reasoning_delta.rb # Reasoning delta event
      reasoning_done.rb  # Reasoning done event
test/
  test_helper.rb         # Minitest configuration with VCR
  riffer_test.rb         # Main module tests
  riffer/
    [feature]_test.rb    # Feature tests mirror lib/riffer/ structure
```

## Development Workflow

### Autoloading with Zeitwerk

- The project uses Zeitwerk for autoloading
- File structure must match module/class names
- No explicit `require` statements needed for lib files
- Special inflections are configured in `lib/riffer.rb` (e.g., `open_ai.rb` → `OpenAI`)

### Adding New Features

1. Create feature files under `lib/riffer/` following Zeitwerk conventions
2. File names should be snake_case, class names should be PascalCase
3. Create corresponding tests in `test/riffer/` mirroring the lib structure
4. Run tests: `rake test`
5. Check code style: `rake standard`

### Adding a New Provider

1. Create `lib/riffer/providers/your_provider.rb` extending `Riffer::Providers::Base`
2. Implement `perform_generate_text(messages, model:)` returning `Riffer::Messages::Assistant`
3. Implement `perform_stream_text(messages, model:)` returning an `Enumerator` yielding stream events
4. Register in `Riffer::Providers::Repository::REPO`
5. Add provider config to `Riffer::Config` if needed
6. Create corresponding test file in `test/riffer/providers/`

### Dependencies

- Add runtime dependencies in `riffer.gemspec` using `spec.add_dependency`
- Add development dependencies in `Gemfile`
- Document significant dependencies in README

### Version Management

- Update version in `lib/riffer/version.rb`
- Follow Semantic Versioning (MAJOR.MINOR.PATCH)
- Update CHANGELOG.md with changes

## AI/Agent Development Context

Since Riffer is an AI framework, when working on AI-related features:

- Consider integration with common AI APIs (OpenAI, Anthropic, Amazon Bedrock, etc.)
- Design for extensibility and plugin architecture
- Handle API rate limiting and retries
- Implement proper error handling for external services
- Consider streaming responses where applicable
- Think about token counting and cost management
- Support async/concurrent operations where beneficial

## Commands Reference

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

# Install gem locally
bundle exec rake install

# Release new version (maintainers only)
bundle exec rake release
```

## Code Patterns

### Module Structure

```ruby
# frozen_string_literal: true

module Riffer::Feature
  class MyClass
    # Implementation
  end
end
```

### Configuration Example

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end
```

### Streaming Example

```ruby
agent = EchoAgent.new
agent.stream('Tell me a story').each do |event|
  print event.content
end
```

## Important Notes

- Always run `rake` (runs both test and standard) before committing
- Keep the README updated with new features
- Follow the Code of Conduct in all interactions
- This gem is MIT licensed – keep license headers consistent
