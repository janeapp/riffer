# Code Style

## Formatting

- Use StandardRB for linting and formatting
- Custom rules are defined in `.standard.yml`
- Run `bin/lint` to check, `bin/lint --fix` to auto-fix

## Required Header

All Ruby files in `lib/` must include:

```ruby
# frozen_string_literal: true
# rbs_inline: enabled
```

## Error Handling

Define custom errors as subclasses of `Riffer::Error`:

```ruby
class MyCustomError < Riffer::Error
end
```

## Comments

- Only add comments when the code is ambiguous or not semantically obvious
- Explain **why** something is done, not **what** is being done
- Comments should add value beyond what the code already expresses

## Hash Key Convention

- Use **symbol keys** for all internal hashes
- Use `JSON.parse(str, symbolize_names: true)` at parse boundaries — never `JSON.parse` followed by `transform_keys(&:to_sym)`
- String keys are only used at serialization boundaries (JSON Schema output, external API payloads)
- Do not write dual-access patterns like `hash[:key] || hash["key"]` — normalize to symbol keys at the boundary instead

## Module Structure

```ruby
# frozen_string_literal: true

module Riffer::Feature
  class MyClass
    # Implementation
  end
end
```
