# Testing

`Riffer::Testing` builds throwaway agents and tools your suite can resolve by identifier or by constant name, and removes them again when the test ends. It exists because agents and tools are looked up by identifier at runtime (see [Looking Up Tools](TOOLS.md#looking-up-tools)) and only **named** classes are found implicitly — an anonymous `Class.new(Riffer::Tool)` never is.

## Setup

Require the adapter for your framework once, in your spec/test helper:

```ruby
# spec/spec_helper.rb
require 'riffer/testing/rspec'
```

```ruby
# test/test_helper.rb
require 'riffer/testing/minitest'
```

Either one adds `stub_agent` and `stub_tool` to every example and cleans up after each one. Neither RSpec nor minitest is a riffer dependency; the adapter files are only loaded when you require them yourself.

## Stubbing a tool

```ruby
it 'answers from the knowledge base' do
  stub_tool('KbSearch') do
    description 'Searches the knowledge base.'

    def call(context:, **)
      text('We are open 9-5.')
    end
  end

  response = SupportAgent.generate('What are your hours?')

  expect(response.content).to include('9-5')
end
```

`stub_tool` returns the class, so you can assert against it or pass it to `uses_tools`:

```ruby
tool = stub_tool('KbSearch') { description 'Searches the knowledge base.' }

stub_agent('FaqAgent') { uses_tools [tool] }
```

The block is evaluated in the new class, so the whole [tool DSL](TOOLS.md) is available inside it — `description`, `params`, `timeout`, `call`.

## Stubbing an agent

```ruby
it 'routes to the FAQ agent' do
  stub_agent('FaqAgent') do # identifier defaults to 'faq_agent', as for a regular agent
    model 'mock/gpt-5-mini'
    instructions 'You are a stub.'
  end

  TriageWorkflow.new.run('What are your hours?')
end
```

Pair it with the [Mock provider](providers/MOCK_PROVIDER.md) to queue deterministic responses.

## Naming a stub

The first argument assigns a top-level constant, so the stub resolves the way a production class does — `Object.const_get('FaqAgent')`, a workflow runner that instantiates agents by class name, a class name stored in a row of data:

```ruby
stub_agent('FaqAgent')

Object.const_get('FaqAgent').identifier # => 'faq_agent'
```

The identifier is derived from the name exactly as it is for a regular agent or tool, and the block can override it like any other config. Skip the name and set the identifier in the block when nothing under test needs a constant, or when the identifier can't derive from one:

```ruby
stub_tool { identifier 'kb-search' }
```

A stub needs a name, an identifier set in its block, or both; `stub_tool` with neither raises `Riffer::ArgumentError`. So does a name that isn't a simple top-level constant name (`'Legacy::Agent'` and `'legacy_agent'` are both rejected — namespaced stubs aren't supported), and so does a name that is **already defined**: riffer adds constants, it never replaces them. Use your framework's `stub_const` when you need a real class swapped out for the duration of a test.

`reset!`, and the adapters that call it, remove the constants the stubs created along with their registrations.

## Stubbing under an intermediate base class

Both helpers take a `base:` — pass your app's intermediate class so the stub lands in the registry the code under test reads:

```ruby
stub_tool('KbSearch', base: ApplicationTool)
```

The stub is always a **direct** subclass of `base`, mirroring how implicit registration works.

## Cleanup

`Riffer::Testing.reset!` removes every stub built since the last reset, newest first, and forgets them. The adapters call it after each example; a no-op when nothing was stubbed.

Without an adapter — a framework riffer ships no wiring for, or a suite that configures its own hooks — include the module and call `reset!` from your own teardown:

```ruby
class MyTestCase < WhateverBase
  include Riffer::Testing

  def teardown
    Riffer::Testing.reset!
    super
  end
end
```

Tracking lives on `Riffer::Testing` itself, so `Riffer::Testing.stub_tool(...)` outside an example and `stub_tool(...)` inside one share one list. Tracking is not synchronized — stub from a single-threaded test, before concurrent lookups begin.

## When a stub leaks

Stubbing an identifier that is already taken raises `Riffer::DuplicateIdentifierError`:

```ruby
stub_tool { identifier 'kb_search' }
stub_tool { identifier 'kb_search' }
# => Riffer::DuplicateIdentifierError: Duplicate identifier "kb_search" for ...
```

Seeing this on the **first** stub in a test means an earlier stub was never removed — usually a missing adapter require in the helper, or a teardown that skips `Riffer::Testing.reset!`. The same error fires when a stub collides with a real class in your app that already claims the identifier; rename the stub or stub under an intermediate `base:`.

A leaked **named** stub leaves its constant behind on top of its registration, and only `reset!` takes a constant back down — so the second test to name it gets a `Riffer::ArgumentError` about the constant rather than a fresh class.

## Registering without a stub

For production wiring, or a test that needs a class registered outside the stub lifecycle, `Riffer::Tool.register` / `unregister` (and the `Riffer::Agent` equivalents) manage the registry by hand. See [Registering a tool explicitly](TOOLS.md#registering-a-tool-explicitly).
