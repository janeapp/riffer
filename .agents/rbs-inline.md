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
#: (String, ?context: Hash[Symbol, untyped]?) -> String
def generate(prompt, context: nil)

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

### Instance variables

The `#:` shorthand on an assignment is a Steep _assertion_ — it types the expression but does
**not declare the ivar**. To declare an ivar's type, use a `# @rbs` comment inside the class
body. `# @rbs` is used **only** for ivar declarations in this codebase; everything else uses
`#:`.

```ruby
class Riffer::Agent::Session
  # @rbs @callbacks: Array[^(Riffer::Messages::Base) -> void]   # instance ivar
end

module Riffer
  # @rbs self.@config: Riffer::Config?                          # class/module-level ivar
end
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

## Optional-dependency types (consumer-safe signatures)

`sig/generated/` ships with the gem and is loaded by downstream projects (`rbs collection` / `rbs -r riffer`). rbs-inline copies a method's `#:` signature **verbatim** into the shipped sig, so **never name an optional-dependency type in a `#:` signature** — `OpenAI::*`, `Anthropic::*`, `Aws::*`, `MCP::*`, `Async::*`, `Zeitwerk::*`, etc. A consumer who installs riffer without that gem would hit `Cannot find type`, because those providers are pluggable and the gems ship no usable RBS of their own.

**Workaround — assert the type inside the method body instead.** An inline assertion (`local = arg #: OpenAI::Models::…`) is a Steep-only hint that rbs-inline does **not** emit into the signature. Leave the SDK param/return `untyped` in the `#:` line, keep every riffer/stdlib param and return typed, and recover the SDK type with a body assertion:

```ruby
#: (untyped) -> String
def extract_content(response)
  message = response #: Anthropic::Models::Message
  message.content&.first&.text || ""        # fully type-checked against the SDK type
end

#: (untyped, state: Hash[Symbol, untyped], yielder: Enumerator::Yielder) -> void
def handle_stream_chunk(chunk, state:, yielder:)
  typed = chunk #: OpenAI::Models::Chat::ChatCompletionChunk
  # ...
end

# When the return value IS the SDK object, type the return `untyped` (no body assertion needed):
#: (Hash[Symbol, untyped]) -> untyped
def execute_generate(params)
  @client.messages.create(**params)
end
```

`test/shipped_signatures_test.rb` enforces this — it fails if any optional-dependency type appears in `sig/generated/` or `sig/manual/`.

### Where stubs and stdlib deps live

- `sig/_private/` — signatures that must **not** ship. RBS **skips** `_`-prefixed directories in library mode, so consumers never load them; riffer's own `steep check` does (via the `Steepfile`). Two kinds, by predictable path: external-gem signatures are named by gem at the top level (`async.rbs`, `mcp.rbs`, `zeitwerk.rbs`, `openai.rbs`, `anthropic.rbs`, `aws-sdk-core/*` — full stubs for RBS-less gems plus arity patches for the provider SDKs); riffer's own hidden stubs mirror `lib/` under `riffer/` (e.g. `riffer/providers/anthropic.rbs` declares the SDK-typed `@client` ivar).
- `sig/manual/` — hand-written riffer-only signatures that are **safe to ship**, for the few things rbs-inline can't generate _at all_ (mirroring `lib/`). In practice that's `extend self` modules (`riffer/agent/run.rbs`, `riffer/helpers/call_or_value.rbs`) and modeling an include applied dynamically (`riffer/tools/toolable.rbs`). SDK-free ivars are **not** hand-written here — declare them inline with `# @rbs` (see "Instance variables"). SDK-typed ivars can't ship, so they go in `_private/riffer/providers/` (`@client`).
- `sig/manifest.yaml` — declares the **stdlib** RBS the shipped sigs reference (`uri`, `net-http`) so `rbs -r riffer` resolves them.

## Workflow

After changing type annotations:

1. Run `bin/rbs` to regenerate `sig/generated/` files
2. Commit both the source changes and the generated `.rbs` files
3. CI checks for drift between source annotations and committed `.rbs` files

Use `bin/rbs-watch` during development to auto-regenerate on file changes.
