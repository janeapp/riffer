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
- Custom RuboCop rules are defined in `.rubocop.yml` - follow these in addition to StandardRB

### Testing

- Use RSpec for all tests
- Test files go in `spec/` directory with `_spec.rb` suffix
- Run tests with `rake spec` or `bundle exec rspec`
- Tests must pass before committing
- Use modern RSpec syntax with `expect` (not `should`)
- Disable monkey patching in specs (already configured)
- **Single Assertion Rule**: Each test should have only one expectation (enforced by RuboCop)

## Project Structure

```
lib/
  riffer.rb              # Main entry point, requires version and defines module
  riffer/
    version.rb           # VERSION constant
    [feature].rb         # Feature modules/classes go here
spec/
  spec_helper.rb         # RSpec configuration
  riffer_spec.rb         # Main module specs
  riffer/
    [feature]_spec.rb    # Feature specs mirror lib/ structure
```

## Development Workflow

### Adding New Features

1. Create feature files under `lib/riffer/`
2. Require new files in `lib/riffer.rb`
3. Create corresponding specs in `spec/riffer/`
4. Run tests: `rake spec`
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

module Riffer
  module Feature
    class MyClass
      # Implementation
    end
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

## Testing Guidelines

### Spec Structure

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Feature do
  describe "#method_name" do
    it "describes behavior" do
      expect(result).to eq(expected)
    end
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
- `rake spec` - Run tests
- `rake standard` - Check code style
- `rake standard:fix` - Auto-fix style issues
- `bundle exec rake install` - Install gem locally
- `bundle exec rake release` - Release new version (maintainers only)

## Important Notes

- Always run `rake` (runs both specs and standard) before committing
- Keep the README updated with new features
- Follow the Code of Conduct in all interactions
- This gem is MIT licensed - keep license headers consistent
