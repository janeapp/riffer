# Code Style

## Formatting

- Use StandardRB for linting and formatting
- Custom rules are defined in `.standard.yml`
- Run `bundle exec rake standard` to check, `bundle exec rake standard:fix` to auto-fix

## Required Header

All Ruby files must include:

```ruby
# frozen_string_literal: true
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

## Module Structure

```ruby
# frozen_string_literal: true

module Riffer::Feature
  class MyClass
    # Implementation
  end
end
```
