# Copilot Instructions for Riffer

## Project Overview

Riffer is a Ruby gem framework for building AI-powered applications and agents. This is a standard Ruby gem structure following modern Ruby best practices.

## Code Style & Standards

### Ruby Version

- Minimum Ruby version: 3.2.0
- Use modern Ruby 3.x features and syntax

### Code Formatting

- Use StandardRB for linting and formatting (configured via `standard` gem)
- All Ruby files must include `# frozen_string_literal: true` at the top
- Follow StandardRB conventions (2-space indentation, double quotes for strings)
- Run `rake standard` to check formatting and `rake standard:fix` to auto-fix
- Custom RuboCop rules are defined in `.standard.yml` - follow these in addition to StandardRB

### Testing

- Use Minitest for all tests with the spec DSL
- Test files go in `test/` directory with `*_test.rb` suffix
- Run tests with `rake test` or `bundle exec rake test`
- Tests must pass before committing
- Use Minitest assertions: `assert_equal`, `assert_instance_of`, `refute_nil`, etc.
- Prefer using `setup` and `teardown` methods for test setup/cleanup

## Project Structure

```
lib/
  riffer.rb              # Main entry point, uses Zeitwerk for autoloading
  riffer/
    version.rb           # VERSION constant
    config.rb            # Configuration class
    core.rb              # Core functionality
    dependency_helper.rb # Dependency management
    agents.rb            # Agents namespace/module
    messages.rb          # Messages namespace/module
    providers.rb         # Providers namespace/module
    storage.rb           # Storage namespace/module
    stream_events.rb     # Stream events namespace/module
    tools.rb             # Tools namespace/module
    agents/
      base.rb            # Base agent class
    messages/
      base.rb            # Base message class
      assistant.rb       # Assistant message
      system.rb          # System message
      user.rb            # User message
      tool.rb            # Tool message
    providers/
      base.rb            # Base provider class
      open_ai.rb         # OpenAI provider
      test.rb            # Test provider
    storage/
      base.rb            # Base storage class
    stream_events/
      base.rb            # Base stream event
      text_delta.rb      # Text delta event
      text_done.rb       # Text done event
    tools/
      base.rb            # Base tool class
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
- Special inflections are configured in [lib/riffer.rb](lib/riffer.rb) (e.g., `open_ai.rb` → `OpenAI`)

### Adding New Features

1. Create feature files under `lib/riffer/` following Zeitwerk conventions
2. File names should be snake_case, class names should be PascalCase
3. Create corresponding tests in `test/riffer/` mirroring the lib structure
4. Run tests: `rake test`
5. Check code style: `rake standard`

### Dependencies

- Add runtime dependencies in `riffer.gemspec` using `spec.add_dependency`
- Add development dependencies in `Gemfile`
- Document significant dependencies in README

### Version Management

- Update version in `lib/riffer/version.rb`
- Follow Semantic Versioning (MAJOR.MINOR.PATCH)
- Update CHANGELOG.md with changes

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

### Error Handling

- Define custom errors as subclasses of `Riffer::Error`
- Use descriptive error messages
- Document errors that can be raised

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

## Testing Guidelines

### Test Structure

```ruby
# frozen_string_literal: true

require "test_helper"

class Riffer::FeatureTest < Minitest::Test
  def test_method_name_describes_behavior
    assert_equal expected, result
  end
end
```

### Test Coverage

- Test public APIs thoroughly
- Test edge cases and error conditions
- Mock external dependencies
- Keep tests fast and isolated

## AI/Agent Development Context

Since Riffer is an AI framework, when working on AI-related features:

- Consider integration with common AI APIs (OpenAI, Anthropic, etc.)
- Design for extensibility and plugin architecture
- Handle API rate limiting and retries
- Implement proper error handling for external services
- Consider streaming responses where applicable
- Think about token counting and cost management
- Support async/concurrent operations where beneficial

## Commands Reference

- `bin/setup` - Install dependencies
- `bin/console` - Interactive console with gem loaded
- `rake test` - Run tests
- `rake standard` - Check code style
- `rake standard:fix` - Auto-fix style issues
- `bundle exec rake install` - Install gem locally
- `bundle exec rake release` - Release new version (maintainers only)

## Important Notes

- Always run `rake` (runs both test and standard) before committing
- Keep the README updated with new features
- Follow the Code of Conduct in all interactions
- This gem is MIT licensed - keep license headers consistent
