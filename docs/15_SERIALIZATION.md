# Serialization

`Riffer::Agent::Serializer` turns a **resolved agent** into a self-contained, provider-neutral data dict (`to_h`) and reconstructs a **runnable agent** from that dict (`from_h`). Use it to persist agent definitions outside of code, or to transfer them across a process/service boundary.

You normally reach it through the delegators on `Riffer::Agent`:

```ruby
dict    = agent.to_h                              # snapshot
rebuilt = Riffer::Agent.from_h(dict, context: {}) # reconstruct
```

The dict is plain data — symbol-keyed, JSON-safe. For the wire, use the JSON helpers, which handle generating and parsing for you:

```ruby
json    = agent.to_json                       # or Riffer::Agent::Serializer.to_json(agent:)
rebuilt = Riffer::Agent.from_json(json, context: {})
```

The hash forms (`to_h` / `from_h`) are public too, if you want to embed the dict in a larger payload. `from_h` expects symbol keys, so parse with `JSON.parse(str, symbolize_names: true)` — or just use `from_json`, which does that for you.

## What the dict carries

```ruby
{
  schema_version:    1,                       # wire format version
  riffer_version:    "0.29.1",                # diagnostic only
  identifier:        "support_agent",
  model:             "openai/gpt-4o",         # resolved "provider/model" string
  instructions:      "You are…",              # resolved system prompt
  model_options:     { temperature: 0.2 },
  provider_options:  { … },                   # see the secrets warning below
  max_steps:         8,                        # integer, or null = unlimited
  structured_output: { type: "object", … },   # JSON Schema, or null
  tools: [ { name:, description:, parameters_schema:, timeout: }, … ]
}
```

### Resolved snapshot

`to_h` reads the agent's **resolved** state, not its raw configuration. By the time you call it, `Agent.new` has already evaluated any `Proc`-based `model`, `instructions`, or `uses_tools` against the agent's own context — so the dict carries plain strings and data, never Procs. The receiver's `context:` drives runtime behavior (tool dispatch); it does **not** re-evaluate baked-in fields.

### Structured output

Structured output crosses as **provider-neutral JSON Schema** (`Riffer::Params#to_json_schema`), never a provider-rendered schema. `from_h` rebuilds a validating `Riffer::Params` via `Riffer::Params.from_json_schema`, so the rebuilt agent both constrains the model and can `parse_and_validate` responses — rendering provider-correct bytes at call time, the same way an in-code agent does.

## Reconstructing tools

Tools cross as `{name, description, parameters_schema, timeout}` descriptors — never code. How a descriptor becomes a runnable tool is controlled by the `tool_resolver:` you pass to `from_h`. The two common shapes:

### In-process (registry lookup)

When the rebuilt agent runs in the **same** codebase that defined the tools (e.g. persisting an agent definition and rehydrating it later), resolve each descriptor back to its real class:

```ruby
rebuilt = Riffer::Agent.from_h(dict, context: {},
  tool_resolver: ->(descriptor) { MyToolRegistry.fetch(descriptor[:name]) })
```

The real classes carry their `#call` bodies, so the agent runs on the default `Inline` runtime — no further wiring.

### Distributed (body-less shells)

When the receiver holds **only the Riffer gem**, the default `tool_resolver` synthesizes body-less **tool shells**. A shell advertises the tool's schema to the LLM but has no `#call` — invoking it in-process raises. Pair the default resolver with a remote `Riffer::Tools::Runtime` that forwards each call back to the origin:

```ruby
rebuilt = Riffer::Agent.from_h(dict, context: {},
  tool_runtime: MyRemoteToolRuntime.new(client: rpc_client))
```

See [`examples/serializer/remote_tool_runtime.rb`](../examples/serializer/remote_tool_runtime.rb) for a complete remote runtime (override `#dispatch_tool_call` to forward over your transport and map failures to `Tools::Response.error`).

You own what a resolved tool does: a resolver may return real in-process classes, shells, or classes that themselves make network calls. Riffer does not require a runtime — it only ships shells by default.

## `max_steps`

Unlimited steps are represented as `nil` at the agent level — set it with `max_steps nil`. `nil` serializes as JSON `null` and round-trips unchanged; a finite integer round-trips as-is. A dict missing the key falls back to the default (16) rather than running unbounded.

## Versioning

`schema_version` is an integer (`Riffer::Agent::Serializer::SCHEMA_VERSION`). `from_h` refuses any version it doesn't recognize with `Riffer::Agent::Serializer::VersionError` (a `Riffer::ArgumentError`). A future incompatible change bumps the integer and adds a back-compat decoder, giving distributed consumers a window to upgrade before the old format is dropped.

## Secrets

`provider_options` and `model_options` **ride on the wire as plain data** — they are part of the dict and _will_ transfer. Care needs to be taken when configuring API keys via `provider_options` and using serialization. Prefer environment/global provider configuration. **Never serialize an agent whose options carry sensitive values** — treat a serialized definition as non-sensitive.

## What does **not** transfer

- **Guardrails and skills** are **not supported yet** — neither is serialized, so a rebuilt agent enforces no guardrails and has no skills catalog. (As a stopgap, a skills-enabled agent's `skill_activate` tool still crosses as an ordinary tool descriptor.) Both are expected to be revisited.

## Next Steps

- [Tools](06_TOOLS.md) - Creating tools
- [Advanced Tools](07_TOOL_ADVANCED.md) - Tool runtime and dispatch
- [Configuration](10_CONFIGURATION.md) - Global configuration
