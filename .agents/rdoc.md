# RDoc Documentation

Use RDoc prose comments for public API descriptions and RBS inline annotations for types.

## Parameters and Return Types

Describe parameters using RDoc labeled list syntax. Use a single `#:` line for the RBS method signature (see [rbs-inline.md](rbs-inline.md) for the full type annotation syntax):

```ruby
# Creates a new agent.
#
# [name] the agent name.
# [options] optional configuration.
#
#--
#: (String, ?options: Hash[Symbol, untyped]) -> void
def initialize(name, options: {})
```

Always add `#--` (RDoc stop directive) on the line before a standalone `#:` type annotation. Without it, RDoc treats `#:` as a label-list marker and corrupts the preceding comment into a `<pre>` block. Inline `#:` on the same line as code (e.g., `attr_reader :name #: String`) does not need this.

## Inline Code

Use `+word+` for single-word inline code. For multi-word expressions (containing spaces, colons, or brackets), use `<tt>multi word expression</tt>`:

```ruby
# Returns +nil+ when no instructions are configured.
# Equivalent to <tt>throw :riffer_interrupt, reason</tt>.
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

Include usage examples as indented code blocks (2 extra spaces of indent):

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
