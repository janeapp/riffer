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

## Comments & Documentation

A comment exists to explain a **why** the code itself cannot — never a **how**, and never a restatement of what the code already says. This bar governs all prose, from inline `#` comments to RDoc descriptions on the public API. Types are not prose's job: parameters, return values, and attribute/constant types live in rbs-inline `#:` annotations (see [rbs-inline.md](rbs-inline.md)).

**What's a comment (in scope):** RDoc descriptions and inline `#` explanations. **Not comments (never touched):** rbs-inline `#:` annotations, magic comments (`frozen_string_literal`, `rbs_inline`), and RDoc directives (`:nodoc:`, `:nocov:`).

### Public surface

Everything public — classes, modules, constants, attributes, public methods, and `protected` subclass-contract methods (e.g. the `pass` / `transform` / `block` helpers a custom `Riffer::Guardrail` calls) — gets **at minimum a very brief description**:

- **One verb-first sentence, one line.** `Creates a new agent.`, `Serializes the definition to JSON.`
- An optional **second sentence is reserved strictly for a "why"** — a non-obvious constraint or rationale the code can't convey. Never a second sentence of "how".
- If a description needs more than one sentence to say _what_ it does, that's a smell the method does too much.
- **Exempt:** a constant whose name and value already carry the full meaning (`VERSION = "0.30.0"`, `PHASES = %i[before after]`) — describe a constant only when its name doesn't; an empty namespace module (a Zeitwerk placeholder with no usable members of its own, e.g. `module Riffer::Messages; end`) — its children are documented individually; and a constructor (`initialize`) — the class doc and RDoc's `::new` already cover plain construction, so describe it only when it carries a contract or non-obvious construction behavior (a raise, a dup guard).

Do not document parameters or return values in prose — the `#:` line is the single source of truth for types. Attributes and constants still carry a brief description on the line above their inline `#:`.

```ruby
# Serializes the agent definition to a transferable JSON payload.
#--
#: (Riffer::Agent) -> String
def serialize(agent)

# The agent's display name.
attr_reader :name #: String
```

### Private methods

A comment survives on a private method **only** if it explains a why a competent reader cannot recover from the code and names alone — a non-local constraint, an external-system quirk, a deliberate non-obvious tradeoff. A description of what it does, or a why that's evident from the code, gets cut.

### Inline comments

Same bar: kept only to explain the why of something genuinely ambiguous. `TODO` / `FIXME` / `HACK` markers are tracked work and stay; `NOTE` / `REVIEW` are subject to the why-rule.

### No history

A comment describes the present, never how the code got there. Change narration — "was X, now Y", "previously used Z" — has no place; the reader cares about what is, not what was. The one thing worth stating is a still-true constraint, and it belongs in the present tense ("the API returns null for empty results — guard"), never told as the story of the bug that revealed it.

### RDoc mechanics

**The `#--` stop directive.** Place `#--` on the line immediately before a **standalone** `#:` type annotation. Without it, RDoc treats `#:` as a label-list marker and corrupts the preceding description into a `<pre>` block. Inline `#:` on the same line as code (attributes, constants) does not need it.

**Raises.** Document a raise **only when it's part of the caller's contract** — something a caller should reasonably anticipate and handle. Skip programmer-error guards and "should never happen" assertions. Reserved for public methods. When the raise condition merely restates the declared `#:` type, phrase it by intent ("Raises Riffer::ArgumentError on an invalid value") rather than re-listing the type union — but keep the runtime constraints a type can't express (enum value sets, coercion rules, validation failure).

```ruby
# Builds a param from a schema hash.
# Raises Riffer::ArgumentError if the schema is missing a +type+.
```

**Examples.** Include an example only when a **consumer is likely to use the thing themselves** — a public entry point they construct, subclass, or call (an `Agent` subclass, `Riffer::Mcp.register`, the `params` DSL). Skip examples on framework-internal types even though they're technically public (value objects the framework constructs and hands back, internal engines). When included, keep them sparing — only when they teach something the signature can't — and write them as indented code blocks (2 extra spaces of indent). Usage walkthroughs belong in `docs/`.

**Inline code formatting.** Use `+word+` for single-word inline code; for multi-word expressions (spaces, colons, brackets) use `<tt>multi word expression</tt>`, e.g. `Equivalent to <tt>throw :riffer_interrupt, reason</tt>`.

**Internal APIs.** Mark with `:nodoc:` to exclude from generated documentation:

```ruby
def internal_method # :nodoc:
end
```

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
