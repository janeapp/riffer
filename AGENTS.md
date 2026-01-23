# Riffer

Ruby gem framework for building AI-powered agents with LLM provider adapters.

## Quick Reference

- **Ruby**: 3.2.0+
- **Lint + Test**: `bundle exec rake`
- **Autoloading**: Zeitwerk (file paths must match module/class names)
- **Model format**: `provider/model` (e.g., `openai/gpt-4`)

## Topic Guides

- [Architecture](.agents/architecture.md) - Core components and project structure
- [Testing](.agents/testing.md) - Minitest spec DSL and VCR cassettes
- [Code Style](.agents/code-style.md) - StandardRB and comment conventions
- [RDoc](.agents/rdoc.md) - Documentation format for public APIs
- [Providers](.agents/providers.md) - Adding new LLM provider adapters

## Commands

| Command | Description |
|---------|-------------|
| `bundle exec rake` | Run tests + lint (default) |
| `bundle exec rake test` | Run tests only |
| `bundle exec rake standard` | Check code style |
| `bundle exec rake standard:fix` | Auto-fix style issues |
| `bin/console` | Interactive console |
