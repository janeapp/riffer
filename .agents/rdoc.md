# RDoc Documentation

Use RDoc prose comments for public API descriptions and RBS inline annotations for types.

## Parameters and Return Types

Describe parameters in the RDoc prose comment. Use a single `#:` line for the RBS method signature (see [rbs-inline.md](rbs-inline.md) for the full type annotation syntax):

```ruby
# Creates a new agent.
#
# +name+ - the agent name.
# +options+ - optional configuration.
#
#: (String, ?options: Hash[Symbol, untyped]) -> void
def initialize(name, options: {})
```

## Attributes and Constants

Use `#:` inline syntax (on the same line) for attribute and constant types:

```ruby
# The agent name.
attr_reader :name #: String

DEFAULT_TIMEOUT = 10 #: Integer
```

## Exceptions

Document with prose:

```ruby
# Raises Riffer::ArgumentError if the name is invalid.
```

## Examples

Include usage examples as indented code blocks:

```ruby
# Creates a new agent.
#
#   agent = MyAgent.new
#   agent.generate('Hello')
#
```

## Internal APIs

Mark internal APIs with `:nodoc:` to exclude from documentation:

```ruby
def internal_method # :nodoc:
end
```
