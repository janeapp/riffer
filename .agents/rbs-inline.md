# RBS Inline

Type annotations are added directly in Ruby source files using [rbs-inline](https://github.com/soutaro/rbs-inline).

## Magic Comment

Every `lib/**/*.rb` file must include the `rbs_inline: enabled` comment on line 2:

```ruby
# frozen_string_literal: true
# rbs_inline: enabled
```

## Annotation Syntax

Two prefixes are used:

- **`#:`** — standalone lines above methods or at the class level (params, return types, instance variables)
- **`#:`** — inline on the same line as code (attributes, constants)

### Method Parameters and Return Types

Use `#:` on standalone lines above the method:

```ruby
#: name: String -- the user name
#: age: Integer
#: return: bool
def valid?(name, age)
```

### Attributes

```ruby
attr_reader :name #: String
attr_reader :items #: Array[String]
```

### Constants

```ruby
VERSION = "1.0.0" #: String
DEFAULTS = {}.freeze #: Hash[Symbol, untyped]
```

### Instance Variables

Use `#:` on standalone lines at the class level:

```ruby
#: @name: String
#: @cache: Hash[String, untyped]
```

### Class Instance Variables

```ruby
#: self.@identifier: String?
#: self.@model: String?
```

## Common Type Patterns

| Pattern                   | Meaning                     |
| ------------------------- | --------------------------- |
| `String?`                 | Optional (String or nil)    |
| `(String \| Integer)`     | Union type                  |
| `Array[String]`           | Typed array                 |
| `Hash[Symbol, untyped]`   | Typed hash                  |
| `^(String) -> void`       | Block/proc type             |
| `singleton(Riffer::Tool)` | Class object (not instance) |
| `bool`                    | Boolean (true or false)     |
| `untyped`                 | Any type                    |
| `void`                    | No meaningful return        |

## Class Methods

Class methods must use `def self.method_name` syntax. `class << self` blocks are **not supported** by rbs-inline.

## Workflow

After changing type annotations:

1. Run `bundle exec rake rbs:generate` to regenerate `sig/generated/` files
2. Commit both the source changes and the generated `.rbs` files
3. CI checks for drift between source annotations and committed `.rbs` files

Use `bundle exec rake rbs:watch` during development to auto-regenerate on file changes.
