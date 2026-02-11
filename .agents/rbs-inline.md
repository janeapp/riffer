# RBS Inline

Type annotations are added directly in Ruby source files using [rbs-inline](https://github.com/soutaro/rbs-inline).

## Magic Comment

Every `lib/**/*.rb` file must include the `rbs_inline: enabled` comment on line 2:

```ruby
# frozen_string_literal: true
# rbs_inline: enabled
```

## Annotation Syntax

The **`#:`** prefix is used — standalone lines above methods (type signatures) or inline on the same line (attributes, constants).

### Method Parameters and Return Types

Use a single `#:` line above the method with the RBS method signature:

```ruby
#: (String, Integer) -> bool
def valid?(name, age)
```

#### Parameter Mapping

| Ruby param                   | RBS signature            |
| ---------------------------- | ------------------------ |
| `def foo(x)`                 | `(Type)`                 |
| `def foo(x = nil)`           | `(?Type?)`               |
| `def foo(x = val)`           | `(?Type)`                |
| `def foo(x:)`                | `(x: Type)`              |
| `def foo(x: nil)`            | `(?x: Type?)`            |
| `def foo(x: val)`            | `(?x: Type)`             |
| `def foo(*args)`             | `(*untyped)`             |
| `def foo(**kwargs)`          | `(**untyped)`            |
| `def foo(&block)` (required) | `() { (Type) -> void }`  |
| `def foo(&block)` (optional) | `() ?{ (Type) -> void }` |
| `def foo(...)`               | `(*untyped, **untyped)`  |

#### Examples

```ruby
# No parameters
#: () -> String
def name

# Positional parameters
#: (String, Integer) -> bool
def valid?(name, age)

# Optional positional parameter
#: (?String?) -> String
def self.identifier(value = nil)

# Required keyword parameters
#: (input: String, output: String) -> Riffer::Evals::Result
def evaluate(input:, output:)

# Mixed keyword parameters (required + optional)
#: (input: String, output: String, ?context: Hash[Symbol, untyped]?) -> Riffer::Evals::Result
def evaluate(input:, output:, context: nil)

# Positional + keyword parameters
#: (String, ?tool_context: Hash[Symbol, untyped]?) -> String
def generate(prompt, tool_context: nil)

# Splat/double-splat
#: (**untyped) -> void
def initialize(**options)

# Forward arguments
#: (*untyped, **untyped) -> String
def self.generate(...)

# Block parameter (required)
#: () { (Riffer::Messages::Base) -> void } -> self
def on_message(&block)

# Block parameter (optional)
#: () ?{ (Riffer::Config) -> void } -> void
def configure(&block)
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

## Workflow

After changing type annotations:

1. Run `bundle exec rake rbs:generate` to regenerate `sig/generated/` files
2. Commit both the source changes and the generated `.rbs` files
3. CI checks for drift between source annotations and committed `.rbs` files

Use `bundle exec rake rbs:watch` during development to auto-regenerate on file changes.
