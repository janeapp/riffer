---
paths: ["lib/**/*.rb", "sig/**/*"]
---

# RBS Inline

Type annotations are added directly in Ruby source files using [rbs-inline](https://github.com/soutaro/rbs-inline).

## Required Header

Every `lib/**/*.rb` file starts with the two-line header `# frozen_string_literal: true` + `# rbs_inline: enabled` — rbs-inline silently skips any file missing the magic comment on line 2.

## Annotation Conventions

The **`#:`** prefix is used — standalone lines above methods (RBS method signatures) or inline on the same line (attributes, constants).

`# @rbs` is used **only** for ivar declarations; everything else uses `#:`. The `#:` shorthand on an assignment is a Steep _assertion_ — it types the expression but does **not declare the ivar**. To declare an ivar's type, use a `# @rbs` comment inside the class body:

```ruby
class Riffer::Agent::Session
  # @rbs @callbacks: Array[^(Riffer::Messages::Base) -> void]   # instance ivar
end

module Riffer
  # @rbs self.@config: Riffer::Config?                          # class/module-level ivar
end
```

## RDoc Conventions

**The `#--` stop directive.** Place `#--` on the line immediately before a **standalone** `#:` type annotation. Without it, RDoc treats `#:` as a label-list marker and corrupts the preceding description into a `<pre>` block. Inline `#:` on the same line as code (attributes, constants) does not need it.

```ruby
# Serializes the agent definition to a transferable JSON payload.
#--
#: (Riffer::Agent) -> String
def serialize(agent)

# The agent's display name.
attr_reader :name #: String
```

**Raises.** Document a raise **only when it's part of the caller's contract** — something a caller should reasonably anticipate and handle. Skip programmer-error guards and "should never happen" assertions. When the raise condition merely restates the declared `#:` type, phrase it by intent ("Raises Riffer::ArgumentError on an invalid value") rather than re-listing the type union.

**Examples.** Include an example only when a **consumer is likely to use the thing themselves** — a public entry point they construct, subclass, or call. Keep them sparing and write them as indented code blocks (2 extra spaces of indent). Usage walkthroughs belong in `docs/`.

**Inline code formatting.** Use `+word+` for single-word inline code; for multi-word expressions (spaces, colons, brackets) use `<tt>multi word expression</tt>`.

**Internal APIs.** Mark with `# :nodoc:` to exclude from generated documentation.

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

- `sig/_private/` — signatures that must **not** ship. RBS **skips** `_`-prefixed directories in library mode, so consumers never load them; riffer's own `steep check` does (via the `Steepfile`). Two kinds, by predictable path: external-gem signatures are named by gem at the top level (`async.rbs`, `mcp.rbs`, `zeitwerk.rbs`, `openai.rbs`, `anthropic.rbs`, `aws-sdk-core/*` — full stubs for RBS-less gems plus arity patches for the provider SDKs); riffer's own hidden stubs mirror `lib/` under `riffer/` (e.g. `riffer/providers/anthropic.rbs` narrows the private `client` method to the SDK-typed client).
- `sig/manual/` — hand-written riffer-only signatures that are **safe to ship**, for the few things rbs-inline can't generate _at all_ (mirroring `lib/`). In practice that's `extend self` modules (`riffer/agent/run.rbs`, `riffer/helpers/call_or_value.rbs`) and modeling an include applied dynamically (`riffer/tools/toolable.rbs`). SDK-free ivars are **not** hand-written here — declare them inline with `# @rbs` (see "Annotation Conventions"). SDK-typed signatures can't ship, so they go in `_private/riffer/providers/` (the narrowed `client`).
- `sig/manifest.yaml` — declares the **stdlib** RBS the shipped sigs reference (`uri`, `net-http`) so `rbs -r riffer` resolves them.

## Workflow

After changing type annotations:

1. Run `bin/rbs` to regenerate `sig/generated/` files
2. Commit both the source changes and the generated `.rbs` files
3. CI checks for drift between source annotations and committed `.rbs` files

Use `bin/rbs-watch` during development to auto-regenerate on file changes.
