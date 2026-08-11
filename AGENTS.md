# Riffer

Ruby gem framework for building AI-powered agents with LLM provider adapters.

## Quick Reference

- **Ruby**: 3.3.0+ (CI: 3.3, 3.4, 4.0)
- **Lint + Test**: `bin/rake` (runs the default task: test + rubocop + steep:check)
- **Autoloading**: Zeitwerk (file paths must match module/class names)
- **Model format**: `provider/model` (e.g., `openai/gpt-4`)
- **Docs**: when adding a public config option or message attribute, update the matching page in `docs/` (e.g., `docs/10_CONFIGURATION.md`, `docs/08_MESSAGES.md`). RDoc ≠ user docs.

## Topic Guides

- [Architecture](.agents/architecture.md) - Core components and project structure
- [Testing](.agents/testing.md) - Minitest spec DSL and VCR cassettes
- [Code Style](.agents/code-style.md) - RuboCop, comment, and RDoc conventions
- [Providers](.agents/providers.md) - Adding new LLM provider adapters
- [RBS Inline](.agents/rbs-inline.md) - Type annotations with rbs-inline

## Commands

All wrappers `exec bundle exec …` under the hood.

| Command         | Description                                  |
| --------------- | -------------------------------------------- |
| `bin/rake`      | Default task: test + rubocop + steep:check   |
| `bin/test`      | Run tests                                    |
| `bin/lint`      | Check code style (pass `-a` to auto-fix)     |
| `bin/typecheck` | Run Steep type checker                       |
| `bin/rbs`       | Generate RBS type signatures                 |
| `bin/rbs-watch` | Watch and regenerate RBS files               |
| `bin/docs`      | Build RDoc HTML                              |
| `bin/build`     | Build the gem package                        |
| `bin/console`   | Interactive console                          |
| `bin/setup`     | Install dependencies                         |

`bin/rake <task>` is the escape hatch for any rake task without a named wrapper.
