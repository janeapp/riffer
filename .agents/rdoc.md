# RDoc Documentation

Use pure RDoc comments for public APIs (not YARD).

## Parameters

Use definition list syntax (`::`):

```ruby
# Creates a new agent.
#
# name:: String - the agent name
# options:: Hash - optional configuration
```

## Return Values

Document with prose:

```ruby
# Returns String - the agent identifier.
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
