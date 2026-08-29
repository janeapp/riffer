# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.44.0](https://github.com/janeapp/riffer/compare/riffer/v0.43.0...riffer/v0.44.0) (2026-08-28)


### Features

* file attachment downloading for user messages ([#407](https://github.com/janeapp/riffer/issues/407)) ([4e78868](https://github.com/janeapp/riffer/commit/4e78868f7d1efe59c35906fff2ba7594ccbd6de7))
* registry liveness, explicit registration, and Riffer::Testing stub factories ([#415](https://github.com/janeapp/riffer/issues/415)) ([6935749](https://github.com/janeapp/riffer/commit/69357496b094fcfa9e72d12a525645374ef6e352))

## [0.43.0](https://github.com/janeapp/riffer/compare/riffer/v0.42.0...riffer/v0.43.0) (2026-08-27)


### ⚠ BREAKING CHANGES

* call_with_validation no longer raises Riffer::ValidationError / Riffer::TimeoutError / Riffer::Error — it always returns a Riffer::Tools::Response. Riffer::TimeoutError has been removed; delete any `rescue Riffer::TimeoutError` and check `response.error_type` instead. Custom runtimes overriding dispatch_tool_call no longer inherit rescues from the base class.

### Features

* tools are the error boundary — call_with_validation never raises ([#412](https://github.com/janeapp/riffer/issues/412)) ([b6db9b6](https://github.com/janeapp/riffer/commit/b6db9b6ab2885d170cbba52c7a571c63b83d892e))

## [0.42.0](https://github.com/janeapp/riffer/compare/riffer/v0.41.0...riffer/v0.42.0) (2026-08-25)


### ⚠ BREAKING CHANGES

* duplicate identifiers among named direct subclasses of Riffer::Tool or Riffer::Agent now raise Riffer::DuplicateIdentifierError on lookup. Agent.find/.all (and the new Tool.find/.all) cover named direct subclasses only - anonymous classes are excluded even with an explicit identifier. Riffer::Helpers::ClassNameConverter is removed; use Riffer::Helpers::Identifier.derive (the separator: keyword is dropped).

### Features

* one identifier registry pattern for tools and agents ([#406](https://github.com/janeapp/riffer/issues/406)) ([72fa7d6](https://github.com/janeapp/riffer/commit/72fa7d6377f903e4a88f9f5ec0e27e51b46dc293))

## [0.41.0](https://github.com/janeapp/riffer/compare/riffer/v0.40.0...riffer/v0.41.0) (2026-08-14)


### ⚠ BREAKING CHANGES

* Inference providers no longer support extra configuration parameters (e.g. timeouts). Instead, a provider client object can be defined in the riffer config directly. Credential and endpoint parameters are still supported.

### Features

* config-injected provider clients, retire provider_options ([#391](https://github.com/janeapp/riffer/issues/391)) ([72fa0e3](https://github.com/janeapp/riffer/commit/72fa0e32ff6cfeee29bae9e2618d001cbc387d99))

## [0.40.0](https://github.com/janeapp/riffer/compare/riffer/v0.39.0...riffer/v0.40.0) (2026-08-12)


### Features

* replace RDoc guide pages with a static docs site ([#390](https://github.com/janeapp/riffer/issues/390)) ([eef94e1](https://github.com/janeapp/riffer/commit/eef94e140b618ae55a0dea2e0e94cf91462ae169))

## [0.39.0](https://github.com/janeapp/riffer/compare/riffer/v0.38.1...riffer/v0.39.0) (2026-07-29)


### Features

* **evals:** expose token usage on evaluation results ([#380](https://github.com/janeapp/riffer/issues/380)) ([32d576e](https://github.com/janeapp/riffer/commit/32d576e492809845c36f44ebf37de3af3b6785b0))

## [0.38.1](https://github.com/janeapp/riffer/compare/riffer/v0.38.0...riffer/v0.38.1) (2026-07-29)


### Performance Improvements

* avoid O(n^2) text accumulation in streaming providers ([#378](https://github.com/janeapp/riffer/issues/378)) ([d344fa7](https://github.com/janeapp/riffer/commit/d344fa7122492d14ee1c91c0be3a88501170e255))

## [0.38.0](https://github.com/janeapp/riffer/compare/riffer/v0.37.1...riffer/v0.38.0) (2026-07-21)


### Features

* record time to first chunk on streaming chat spans ([#369](https://github.com/janeapp/riffer/issues/369)) ([133b019](https://github.com/janeapp/riffer/commit/133b0197dd358ae1cd37adbeb7b5df7446b0cbde))

## [0.37.1](https://github.com/janeapp/riffer/compare/riffer/v0.37.0...riffer/v0.37.1) (2026-07-13)


### Bug Fixes

* keep multi-line skill descriptions within their catalog list item ([#360](https://github.com/janeapp/riffer/issues/360)) ([335e913](https://github.com/janeapp/riffer/commit/335e9130f5fe73e7bfe9b24faa9bc6fb9f0d6794)), closes [#355](https://github.com/janeapp/riffer/issues/355)

## [0.37.0](https://github.com/janeapp/riffer/compare/riffer/v0.36.0...riffer/v0.37.0) (2026-07-10)


### Features

* **providers:** first-class provider registration API ([#353](https://github.com/janeapp/riffer/issues/353)) ([551d80b](https://github.com/janeapp/riffer/commit/551d80bf615de813629768156c6674d232877150))

## [0.36.0](https://github.com/janeapp/riffer/compare/riffer/v0.35.0...riffer/v0.36.0) (2026-07-03)


### ⚠ BREAKING CHANGES

* config.metrics, the Riffer::Metrics module, and Riffer::Metrics::Otel are removed. Hosts wiring a metrics backend must drop that configuration.

### Features

* remove the metrics primitive ([#347](https://github.com/janeapp/riffer/issues/347)) ([70a838e](https://github.com/janeapp/riffer/commit/70a838e9d49da12f89886c6e6f7bca35f427f77c))

## [0.35.0](https://github.com/janeapp/riffer/compare/riffer/v0.34.0...riffer/v0.35.0) (2026-06-25)


### Features

* per-call tags: for Agent#generate and #stream ([#339](https://github.com/janeapp/riffer/issues/339)) ([ddfda89](https://github.com/janeapp/riffer/commit/ddfda8929ca3b594415f827957d8c91104387317))

## [0.34.0](https://github.com/janeapp/riffer/compare/riffer/v0.33.0...riffer/v0.34.0) (2026-06-22)


### ⚠ BREAKING CHANGES

* **telemetry:** `config.tracing.tracer_provider` and `config.metrics.meter_provider` are removed. Assign the OTEL backend instead: `config.tracing.backend = Riffer::Tracing::Otel.build` (pass `provider:` to override the global provider).

### Features

* emit a riffer.guardrail.duration metric for guardrail execution ([#338](https://github.com/janeapp/riffer/issues/338)) ([7b0dfb0](https://github.com/janeapp/riffer/commit/7b0dfb014f710d839e53d25ee345df5b404c8c60))
* **telemetry:** pluggable tracing/metrics backend (OTEL opt-in) ([#329](https://github.com/janeapp/riffer/issues/329)) ([d647f54](https://github.com/janeapp/riffer/commit/d647f54b814bb8e331b89811c2ed661d6534b20c))

## [0.33.0](https://github.com/janeapp/riffer/compare/riffer/v0.32.1...riffer/v0.33.0) (2026-06-18)


### ⚠ BREAKING CHANGES

* reported input_tokens grows by the cache token counts on Anthropic and Bedrock, and output_tokens grows by the thinking token count on Gemini, whenever those features are active.

### Features

* add the Riffer::Metrics OpenTelemetry port foundation ([#325](https://github.com/janeapp/riffer/issues/325)) ([92d060c](https://github.com/janeapp/riffer/commit/92d060c9f006f9f6e904aa57e749909f360b8cd3))
* add tracing foundation with optional OTEL backend ([#307](https://github.com/janeapp/riffer/issues/307)) ([938194c](https://github.com/janeapp/riffer/commit/938194caa7c9bfcdada9039047adf2e9fd599c27))
* compute per-model cost on token usage ([#322](https://github.com/janeapp/riffer/issues/322)) ([f637f73](https://github.com/janeapp/riffer/commit/f637f73875cb5aa4563b5bae992269b5d7185ae2))
* emit a chat span per LLM call with normalized finish reasons ([#312](https://github.com/janeapp/riffer/issues/312)) ([42f39dd](https://github.com/janeapp/riffer/commit/42f39dd244295cf8d398fd7daf14c33d2a169c32))
* emit an execute_guardrail span per guardrail ([#324](https://github.com/janeapp/riffer/issues/324)) ([b280c71](https://github.com/janeapp/riffer/commit/b280c71bb8089ed7e948d8966f841535178f167f))
* emit an execute_tool span per tool call ([#318](https://github.com/janeapp/riffer/issues/318)) ([e548450](https://github.com/janeapp/riffer/commit/e548450a980e6a03d06bda488ab94704ad33a37a))
* emit gen_ai.client.operation.duration metric ([#326](https://github.com/janeapp/riffer/issues/326)) ([a9399b8](https://github.com/janeapp/riffer/commit/a9399b8f1b10bc947b1e0716a483e2921ab2a852))
* emit gen_ai.client.token.usage metric ([#327](https://github.com/janeapp/riffer/issues/327)) ([f77f0f7](https://github.com/janeapp/riffer/commit/f77f0f7cd8db7cbd3a3a36f10e4ab08e70e909a0))
* emit invoke_agent span per agent run ([#310](https://github.com/janeapp/riffer/issues/310)) ([49c8c79](https://github.com/janeapp/riffer/commit/49c8c79f3ba9c13c83ed6cd0e427e842a0459176))
* emit riffer.gen_ai.cost metric from TokenUsage cost ([#328](https://github.com/janeapp/riffer/issues/328)) ([1ee4772](https://github.com/janeapp/riffer/commit/1ee47726def4ca2e812e88157efce1bf2a8d2e69))
* support user-explicit skill activation and dedupe re-activations ([#305](https://github.com/janeapp/riffer/issues/305)) ([f95b908](https://github.com/janeapp/riffer/commit/f95b90897f60fc4b8f930297e0b22ce61a1a330f))
* surface cost on LLM-call and run spans ([#323](https://github.com/janeapp/riffer/issues/323)) ([a9074b4](https://github.com/janeapp/riffer/commit/a9074b47defb4a0426c8a51dd90b60260098a14b))


### Code Refactoring

* normalize token usage semantics across providers ([#309](https://github.com/janeapp/riffer/issues/309)) ([990f86d](https://github.com/janeapp/riffer/commit/990f86d9ec74cfe85329a7ab583d51b72628c85f))

## [0.32.1](https://github.com/janeapp/riffer/compare/riffer/v0.32.0...riffer/v0.32.1) (2026-06-10)


### Bug Fixes

* respect disable-model-invocation in skills ([#303](https://github.com/janeapp/riffer/issues/303)) ([2cf8719](https://github.com/janeapp/riffer/commit/2cf8719ecc36d748fabf7f03c8427e2b3043d30c))

## [0.32.0](https://github.com/janeapp/riffer/compare/riffer/v0.31.0...riffer/v0.32.0) (2026-06-08)


### ⚠ BREAKING CHANGES

* `TokenUsage#cache_creation_tokens` is renamed to `cache_write_tokens` (also reflected in `TokenUsage#to_h`). Update any code reading that attribute or hash key.
* apply module/class conventions consistently ([#298](https://github.com/janeapp/riffer/issues/298))

### Features

* add Bedrock prompt caching and surface cached tokens ([#300](https://github.com/janeapp/riffer/issues/300)) ([407390b](https://github.com/janeapp/riffer/commit/407390b505a3af6b881c5204d856a8e9ceddbed9))
* add progressive discovery for MCP tools by default ([0a37485](https://github.com/janeapp/riffer/commit/0a37485dd59e08a0ba0ca8d1046e3313914f72a5))


### Code Refactoring

* apply module/class conventions consistently ([#298](https://github.com/janeapp/riffer/issues/298)) ([76a3131](https://github.com/janeapp/riffer/commit/76a3131f800ba026c07cc194ab2879279134e865))

## [0.31.0](https://github.com/janeapp/riffer/compare/riffer/v0.30.0...riffer/v0.31.0) (2026-06-03)


### Features

* forward session: through Agent.from_h/from_json for history seeding ([#295](https://github.com/janeapp/riffer/issues/295)) ([0b2eaa2](https://github.com/janeapp/riffer/commit/0b2eaa27f5154bfd61891d4e93b8938f7dce2ce6))

## [0.30.0](https://github.com/janeapp/riffer/compare/riffer/v0.29.1...riffer/v0.30.0) (2026-06-03)


### ⚠ BREAKING CHANGES

* unlimited max_steps is now represented as `nil` at the agent level (set via `max_steps nil`), not Float::INFINITY — Riffer::Agent::Config#max_steps may be nil and is no longer normalized. Riffer::Params parameter types are typed Module (widened from Class) to honestly include Riffer::Params::Boolean, which is a Module.

### Features

* Riffer::Agent::Serializer for transferable agent definitions ([#293](https://github.com/janeapp/riffer/issues/293)) ([99134b0](https://github.com/janeapp/riffer/commit/99134b0bf52bccfd727e52349aba8432389775be))

## [0.29.1](https://github.com/janeapp/riffer/compare/riffer/v0.29.0...riffer/v0.29.1) (2026-06-01)


### Bug Fixes

* **rbs:** ship consumer-safe RBS signatures ([#286](https://github.com/janeapp/riffer/issues/286)) ([ac8ce6c](https://github.com/janeapp/riffer/commit/ac8ce6c40ab665456cee6cd9275649024492f4a0))

## [0.29.0](https://github.com/janeapp/riffer/compare/riffer/v0.28.0...riffer/v0.29.0) (2026-05-29)


### ⚠ BREAKING CHANGES

* move leaf types out of root Riffer namespace ([#282](https://github.com/janeapp/riffer/issues/282))
* Public API reshape on `Riffer::Agent`. Downstream consumers must migrate the following surfaces:

### Features

* add bin/ wrappers for common dev commands ([#276](https://github.com/janeapp/riffer/issues/276)) ([6812ba2](https://github.com/janeapp/riffer/commit/6812ba254d0b9220dae5ed0bbfbc4d8fee5b14e1))
* add OpenRouter provider ([#280](https://github.com/janeapp/riffer/issues/280)) ([0d615b6](https://github.com/janeapp/riffer/commit/0d615b60ec3bb65091df16142a8e67f2afceea74))


### Code Refactoring

* extract Riffer::Agent::Run, eagerly resolve per-agent state ([#268](https://github.com/janeapp/riffer/issues/268)) ([1d9e141](https://github.com/janeapp/riffer/commit/1d9e141e8a381eaac13f107ca29b726b4d84b3f3))
* move leaf types out of root Riffer namespace ([#282](https://github.com/janeapp/riffer/issues/282)) ([3637a53](https://github.com/janeapp/riffer/commit/3637a53ae8160e70bdaeae3d49812adfefac2c4b))

## [0.28.0](https://github.com/janeapp/riffer/compare/riffer/v0.27.2...riffer/v0.28.0) (2026-05-08)


### ⚠ BREAKING CHANGES

* Custom subclasses of Riffer::ToolRuntime that override around_tool_call or dispatch_tool_call must accept the new assistant_message: kwarg (or **kwargs). Existing overrides that omit it will raise ArgumentError: unknown keyword: :assistant_message.

### Features

* add history mutation API to Riffer::Agent ([#249](https://github.com/janeapp/riffer/issues/249)) ([d980daa](https://github.com/janeapp/riffer/commit/d980daa1526e476ce08b299be84e93257b746a1b))
* forward assistant_message to ToolRuntime hooks ([#247](https://github.com/janeapp/riffer/issues/247)) ([3d5f935](https://github.com/janeapp/riffer/commit/3d5f935bf136a39e8fbef1b0a0728fcb87ef0de0))

## [0.27.2](https://github.com/janeapp/riffer/compare/riffer/v0.27.1...riffer/v0.27.2) (2026-05-04)


### Bug Fixes

* validate tools at the class-level resolution boundary ([#242](https://github.com/janeapp/riffer/issues/242)) ([7abbcd6](https://github.com/janeapp/riffer/commit/7abbcd607f1cbb3e1d45f5d148d902170a78af06))

## [0.27.1](https://github.com/janeapp/riffer/compare/riffer/v0.27.0...riffer/v0.27.1) (2026-05-04)


### Bug Fixes

* validate tools before sending them to providers ([#240](https://github.com/janeapp/riffer/issues/240)) ([537e2ab](https://github.com/janeapp/riffer/commit/537e2abf16542ba9d19d9fd3ffa649aefbca9c10))

## [0.27.0](https://github.com/janeapp/riffer/compare/riffer/v0.26.0...riffer/v0.27.0) (2026-05-01)


### Features

* integrate MCP server tools into agent tool resolution ([6c7a09a](https://github.com/janeapp/riffer/commit/6c7a09a1797dcc8fbafd198665fb665ede93f009))


### Bug Fixes

* close streaming HTTP connections when consumer raises ([#235](https://github.com/janeapp/riffer/issues/235)) ([2a51a10](https://github.com/janeapp/riffer/commit/2a51a106d0f9d1410040c6b3a887722378a0dc14))

## [0.26.0](https://github.com/janeapp/riffer/compare/riffer/v0.25.0...riffer/v0.26.0) (2026-04-29)


### Features

* model-aware skills adapter selection ([#232](https://github.com/janeapp/riffer/issues/232)) ([74a5323](https://github.com/janeapp/riffer/commit/74a5323945f3f6f30538d472400cc5fe27b588da))

## [0.25.0](https://github.com/janeapp/riffer/compare/riffer/v0.24.2...riffer/v0.25.0) (2026-04-29)


### ⚠ BREAKING CHANGES

* Removed Riffer::Skills::Adapter#activate_tool. Set the activation tool via Riffer.config.skills.default_activate_tool, or per-agent with `skills do; activate_tool MyTool; end`.
* Riffer::Skills::Adapter.new now requires skill_activate_tool:. The agent wires this up; only matters if you construct an adapter yourself. Custom adapters that override #initialize must call super.

### Features

* class-level tool resolution; lift activation tool to global config ([#230](https://github.com/janeapp/riffer/issues/230)) ([936c4ba](https://github.com/janeapp/riffer/commit/936c4baa6beff4f2cd6c87bfe90be8c20a7f30e1))

## [0.24.2](https://github.com/janeapp/riffer/compare/riffer/v0.24.1...riffer/v0.24.2) (2026-04-23)


### Bug Fixes

* **providers:** surface Bedrock stream errors and concat text blocks ([#222](https://github.com/janeapp/riffer/issues/222)) ([d30421e](https://github.com/janeapp/riffer/commit/d30421e48ed50e6517b834aa7281ee5349d66309))

## [0.24.1](https://github.com/janeapp/riffer/compare/riffer/v0.24.0...riffer/v0.24.1) (2026-04-23)


### Bug Fixes

* disable gzip on Anthropic stream to avoid SSE buffering ([#220](https://github.com/janeapp/riffer/issues/220)) ([ee2aaca](https://github.com/janeapp/riffer/commit/ee2aaca06eaefb12e5b6cbc3bde48ba8f3ea4ee8))

## [0.24.0](https://github.com/janeapp/riffer/compare/riffer/v0.23.0...riffer/v0.24.0) (2026-04-20)


### Features

* add optional message id generation ([#210](https://github.com/janeapp/riffer/issues/210)) ([0f9e20d](https://github.com/janeapp/riffer/commit/0f9e20dcd2d69a49fe5da71be3f0b9deb0a046a4))

## [0.23.0](https://github.com/janeapp/riffer/compare/riffer/v0.22.0...riffer/v0.23.0) (2026-04-15)


### Features

* add Gemini provider ([#199](https://github.com/janeapp/riffer/issues/199)) ([d0f0823](https://github.com/janeapp/riffer/commit/d0f08237052258be64a8fb63e0d1c23508258176))

## [0.22.0](https://github.com/janeapp/riffer/compare/riffer/v0.21.0...riffer/v0.22.0) (2026-04-09)


### ⚠ BREAKING CHANGES

* `Tool.name` returns `namespace/tool_name` instead of `namespace__tool_name`.

### Features

* use human-friendly `/` separator for tool names ([#202](https://github.com/janeapp/riffer/issues/202)) ([8dda251](https://github.com/janeapp/riffer/commit/8dda251ff6d91a6cebbbb82082b7ac21c2a51253))


### Bug Fixes

* release 0.22.0 ([#204](https://github.com/janeapp/riffer/issues/204)) ([860a500](https://github.com/janeapp/riffer/commit/860a500bb6e991de8018b43cda0c5f2662e22402))

## [0.21.0](https://github.com/janeapp/riffer/compare/riffer/v0.20.0...riffer/v0.21.0) (2026-04-09)


### Features

* **amazon_bedrock:** support S3 URI file sources ([#190](https://github.com/janeapp/riffer/issues/190)) ([243e5b1](https://github.com/janeapp/riffer/commit/243e5b12407cac800b6cf0968a24989924932c26))
* normalize consecutive same-role messages before provider serialization ([#201](https://github.com/janeapp/riffer/issues/201)) ([1ac986d](https://github.com/janeapp/riffer/commit/1ac986dd54a3fb9859ae05d57c49176e37704195))

## [0.20.0](https://github.com/janeapp/riffer/compare/riffer/v0.19.0...riffer/v0.20.0) (2026-03-26)


### Features

* add fibers tool runtime using async gem ([#178](https://github.com/janeapp/riffer/issues/178)) ([67fd344](https://github.com/janeapp/riffer/commit/67fd34493126559b99a00cc3402a6adabefc14ea))


### Bug Fixes

* correct RDoc formatting for docs.riffer.ai ([#182](https://github.com/janeapp/riffer/issues/182)) ([2f2fbc9](https://github.com/janeapp/riffer/commit/2f2fbc997281ef4a546a58e44233e325a25c41d5))

## [0.19.0](https://github.com/janeapp/riffer/compare/riffer/v0.18.0...riffer/v0.19.0) (2026-03-25)


### Features

* Add Azure OpenAI provider ([#167](https://github.com/janeapp/riffer/issues/167)) ([5d34fcd](https://github.com/janeapp/riffer/commit/5d34fcd4a98a6bcfa768c50fea7c25959eca5f1d))
* expose message history in eval results ([#171](https://github.com/janeapp/riffer/issues/171)) ([c8b1aec](https://github.com/janeapp/riffer/commit/c8b1aeceb40a173c70d4be445fb82bba10113b87))
* provide agent context to runners ([#181](https://github.com/janeapp/riffer/issues/181)) ([23c9282](https://github.com/janeapp/riffer/commit/23c9282d4f2076d1ff6185f99bcf855f158ccb0d))

## [0.18.0](https://github.com/janeapp/riffer/compare/riffer/v0.17.0...riffer/v0.18.0) (2026-03-13)


### Features

* add support for agent skills ([#151](https://github.com/janeapp/riffer/issues/151)) ([8847d54](https://github.com/janeapp/riffer/commit/8847d54dede875f207d0e0b28bb64039d3c2e69f))
* Unify generate/stream API with multi-turn support, remove resume methods ([#165](https://github.com/janeapp/riffer/issues/165)) ([58826df](https://github.com/janeapp/riffer/commit/58826df27806bb10afe1c7ad94322cc643d049f9))

## [0.17.0](https://github.com/janeapp/riffer/compare/riffer/v0.16.1...riffer/v0.17.0) (2026-03-06)


### ⚠ BREAKING CHANGES

* rename `tool_context` to `context` ([#159](https://github.com/janeapp/riffer/issues/159))

### Features

* add experimental ToolRuntime abstraction for tool execution ([#156](https://github.com/janeapp/riffer/issues/156)) ([0ca7563](https://github.com/janeapp/riffer/commit/0ca7563df9f0a555e5fa6a1f3065d5f072abbf7e))
* add interrupt! public method for clean loop interrupts ([#155](https://github.com/janeapp/riffer/issues/155)) ([a4cc877](https://github.com/janeapp/riffer/commit/a4cc8778b754e3932748454446eebd71795ad5e1))
* add support for dynamic instructions ([#158](https://github.com/janeapp/riffer/issues/158)) ([408e09c](https://github.com/janeapp/riffer/commit/408e09c585142caca173a232ec20dde012553dc0))
* auto-derive step offset on resume for max_steps enforcement ([#154](https://github.com/janeapp/riffer/issues/154)) ([fb97dbe](https://github.com/janeapp/riffer/commit/fb97dbec4a0edf5ea1e46bf44b93170663db04ef))


### Bug Fixes

* resolve edge cases in generate/resume and streaming methods ([#162](https://github.com/janeapp/riffer/issues/162)) ([f74d373](https://github.com/janeapp/riffer/commit/f74d373fb3cb8bb2d6c4617dd29ba3b30a3a8177))


### Code Refactoring

* rename `tool_context` to `context` ([#159](https://github.com/janeapp/riffer/issues/159)) ([5be7214](https://github.com/janeapp/riffer/commit/5be7214934866dfa24062b248c59324178f9956a))

## [0.16.1](https://github.com/janeapp/riffer/compare/riffer/v0.16.0...riffer/v0.16.1) (2026-03-03)


### Bug Fixes

* use anyOf for optional enum params in strict JSON Schema ([#152](https://github.com/janeapp/riffer/issues/152)) ([2c7fc4d](https://github.com/janeapp/riffer/commit/2c7fc4db4eda33f6fbcbe4b3799b602050af058d))

## [0.16.0](https://github.com/janeapp/riffer/compare/riffer/v0.15.1...riffer/v0.16.0) (2026-02-27)


### Features

* add Riffer::Boolean sentinel type for boolean params ([#147](https://github.com/janeapp/riffer/issues/147)) ([5337cf3](https://github.com/janeapp/riffer/commit/5337cf3820d54cf9e03a630ca32b8a7f59347221))
* nested params DSL and strict schema for all providers ([#144](https://github.com/janeapp/riffer/issues/144)) ([2984855](https://github.com/janeapp/riffer/commit/2984855c64a1d0b421497aa81c5e0a393d443e46))

## [0.15.1](https://github.com/janeapp/riffer/compare/riffer/v0.15.0...riffer/v0.15.1) (2026-02-25)


### Bug Fixes

* address claude code review issues from PR [#140](https://github.com/janeapp/riffer/issues/140) ([#142](https://github.com/janeapp/riffer/issues/142)) ([f927c0c](https://github.com/janeapp/riffer/commit/f927c0c1fc472f859d54b1e1d2a02709f53ac973))

## [0.15.0](https://github.com/janeapp/riffer/compare/riffer/v0.14.0...riffer/v0.15.0) (2026-02-25)


### Features

* store structured output in assistant messages ([#140](https://github.com/janeapp/riffer/issues/140)) ([9cdb2e2](https://github.com/janeapp/riffer/commit/9cdb2e2adad5eab6745212e573534d3369528ccb))

## [0.14.0](https://github.com/janeapp/riffer/compare/riffer/v0.13.0...riffer/v0.14.0) (2026-02-24)


### Features

* add file attachment support for user messages ([#129](https://github.com/janeapp/riffer/issues/129)) ([0d08eb1](https://github.com/janeapp/riffer/commit/0d08eb140e4094a729b1da5e3fddb57b251bf6f3))
* add max_steps option to Agent ([#121](https://github.com/janeapp/riffer/issues/121)) ([fbc0391](https://github.com/janeapp/riffer/commit/fbc0391d157db587c0293255587a70141a7b588f))
* add structured output support for agents ([#128](https://github.com/janeapp/riffer/issues/128)) ([99be155](https://github.com/janeapp/riffer/commit/99be15567747427830fdb75b585715f013857f6f))
* add web_search option for OpenAI and Anthropic providers ([#126](https://github.com/janeapp/riffer/issues/126)) ([7e7e793](https://github.com/janeapp/riffer/commit/7e7e793a4ff746d7238074a21b9cd62a846e7c99))
* interruptible callbacks via throw/catch ([#119](https://github.com/janeapp/riffer/issues/119)) ([f5985e6](https://github.com/janeapp/riffer/commit/f5985e627737b28ebbf7ed7262e62496836acf1f))
* replace eval prompt API with semantic fields ([#132](https://github.com/janeapp/riffer/issues/132)) ([5d99d5a](https://github.com/janeapp/riffer/commit/5d99d5af408e4e70ae66c975d1b40d60a209f5a6))
* replace Profile/Metric eval system with EvaluatorRunner ([#138](https://github.com/janeapp/riffer/issues/138)) ([ebf2696](https://github.com/janeapp/riffer/commit/ebf2696dfce814be43278aa9857285c21b3894bf))
* support dynamic model selection via lambda ([#127](https://github.com/janeapp/riffer/issues/127)) ([c59cf96](https://github.com/janeapp/riffer/commit/c59cf96efb5a4f5d0bc947441fa3aeeea3b4e5f3))


### Bug Fixes

* add --comment flag to claude code review prompt ([#122](https://github.com/janeapp/riffer/issues/122)) ([534bd59](https://github.com/janeapp/riffer/commit/534bd59c389233466824090b7bdfed976870d9f1))
* add RBS annotations to web search constants and fix test provider docs ([#130](https://github.com/janeapp/riffer/issues/130)) ([7cebe05](https://github.com/janeapp/riffer/commit/7cebe0506eafaa35abe2de74997af479a3776a7d))
* correct Amazon Bedrock model options to use Converse API structure ([#133](https://github.com/janeapp/riffer/issues/133)) ([3af4562](https://github.com/janeapp/riffer/commit/3af45620fc47d1b98961eb45d79a905a7d2cac82))
* widen run_eval input type to accept String or messages array ([#124](https://github.com/janeapp/riffer/issues/124)) ([f96214c](https://github.com/janeapp/riffer/commit/f96214c5b602c3469edca2ac9d0b856d1e23c630))

## [0.13.0](https://github.com/janeapp/riffer/compare/riffer/v0.12.0...riffer/v0.13.0) (2026-02-12)


### Features

* remove identifiers from evals and guardrails ([#112](https://github.com/janeapp/riffer/issues/112)) ([7b60707](https://github.com/janeapp/riffer/commit/7b60707206e53451f5bee2faf1c12a75eaf26d98))

## [0.12.0](https://github.com/janeapp/riffer/compare/riffer/v0.11.0...riffer/v0.12.0) (2026-02-11)


### ⚠ BREAKING CHANGES

* Agent#generate now returns Riffer::Agent::Response instead of String. Use response.content or response.to_s for the text.

### Features

* add Claude Code Review GitHub Action ([#108](https://github.com/janeapp/riffer/issues/108)) ([f4b281c](https://github.com/janeapp/riffer/commit/f4b281c43e6ad50430c38323bcb876b60efc994a))
* add evals primitive for LLM-as-judge evaluations ([#101](https://github.com/janeapp/riffer/issues/101)) ([8fd7b36](https://github.com/janeapp/riffer/commit/8fd7b369f2bd0236ea4c7d30cc12e71b960211dd))
* add guardrails primitive for input/output processing ([#100](https://github.com/janeapp/riffer/issues/100)) ([48d8bad](https://github.com/janeapp/riffer/commit/48d8badce98c0bf9110bafebd3097e25f46c8444))
* add inline RBS type annotations with Steep type checking ([#103](https://github.com/janeapp/riffer/issues/103)) ([02ae559](https://github.com/janeapp/riffer/commit/02ae559fa580ef4353bd969f2e50e056ab538e2d))


### Bug Fixes

* correct RBS inline annotations and remove ivar declarations ([#109](https://github.com/janeapp/riffer/issues/109)) ([d59076d](https://github.com/janeapp/riffer/commit/d59076d40b88f581b51ddbb9ee3d50ed57e84451))


### Miscellaneous Chores

* set next version ([#111](https://github.com/janeapp/riffer/issues/111)) ([faf41b9](https://github.com/janeapp/riffer/commit/faf41b92032e302c3f0d2d06ab93140137c1b199))

## [0.11.0](https://github.com/janeapp/riffer/compare/riffer/v0.10.0...riffer/v0.11.0) (2026-02-04)


### Features

* add class methods for generate and stream to Riffer::Agent ([#97](https://github.com/janeapp/riffer/issues/97)) ([597636a](https://github.com/janeapp/riffer/commit/597636aef7498fe34c975522930e3fd0939a2ea0))
* Add token usage tracking in Riffer::Agent ([#102](https://github.com/janeapp/riffer/pull/102)) ([6044914](https://github.com/janeapp/riffer/commit/60449148074e42a8b36f0b6977be005b06993d9c))

## [0.10.0](https://github.com/janeapp/riffer/compare/riffer/v0.9.0...riffer/v0.10.0) (2026-01-30)


### Features

* update class name conversion to support configurable namespace separators ([#96](https://github.com/janeapp/riffer/issues/96)) ([e7091e9](https://github.com/janeapp/riffer/commit/e7091e95210c2df27138e61e64032d52ecf174e1))


### Bug Fixes

* handle multiple tools correctly for bedrock ([#95](https://github.com/janeapp/riffer/issues/95)) ([50ae6f6](https://github.com/janeapp/riffer/commit/50ae6f6cd803d5e95b79cb6ceafca5b2d9b4a52c))
* update class name conversion to use double underscore format ([#93](https://github.com/janeapp/riffer/issues/93)) ([f6ffad7](https://github.com/janeapp/riffer/commit/f6ffad775a2d8254543dd7819dca93c15f514742))

## [0.9.0](https://github.com/janeapp/riffer/compare/riffer/v0.8.0...riffer/v0.9.0) (2026-01-28)


### Features

* implement Riffer::Tools::Response for consistent tool result handling ([#91](https://github.com/janeapp/riffer/issues/91)) ([df44f1f](https://github.com/janeapp/riffer/commit/df44f1fe8ff0b5bea73a2df8d6c0b8359e6c47f3))

## [0.8.0](https://github.com/janeapp/riffer/compare/riffer/v0.7.0...riffer/v0.8.0) (2026-01-26)


### Features

* add anthropic provider support ([#89](https://github.com/janeapp/riffer/issues/89)) ([338674e](https://github.com/janeapp/riffer/commit/338674e794535b2559ce4dca5d36e09e9512b94c))
* add on_message callback for real-time message emission ([#87](https://github.com/janeapp/riffer/issues/87)) ([92e6f91](https://github.com/janeapp/riffer/commit/92e6f919b9facee9a2fb6234c1bdd69b525dbf21))
* add timeout functionality to tools ([#86](https://github.com/janeapp/riffer/issues/86)) ([3b7d9af](https://github.com/janeapp/riffer/commit/3b7d9afeed829001de0f6524694c193d54f1e7af))
* better docs ([#84](https://github.com/janeapp/riffer/issues/84)) ([630580a](https://github.com/janeapp/riffer/commit/630580ae08a86dfa5ab1f75ebb229db7cff6344d))

## [0.7.0](https://github.com/janeapp/riffer/compare/riffer/v0.6.1...riffer/v0.7.0) (2026-01-21)


### Features

* tool calling support ([#82](https://github.com/janeapp/riffer/issues/82)) ([0b2676a](https://github.com/janeapp/riffer/commit/0b2676a77e93b3fd55041e66a5c8c0ab6762e3d2))

## [0.6.1](https://github.com/janeapp/riffer/compare/riffer/v0.6.0...riffer/v0.6.1) (2026-01-16)


### Bug Fixes

* remove unnecessary require statement for openai ([#76](https://github.com/janeapp/riffer/issues/76)) ([76b76f8](https://github.com/janeapp/riffer/commit/76b76f8c063fbf6aacfcf838c2d4f2fd37c54279))

## [0.6.0](https://github.com/janeapp/riffer/compare/riffer/v0.5.1...riffer/v0.6.0) (2026-01-14)


### Features

* aws bedrock provider ([#73](https://github.com/janeapp/riffer/issues/73)) ([428ae90](https://github.com/janeapp/riffer/commit/428ae902db90c2d3765186ea06d76ee379b3eae7))
* reasoning support ([#75](https://github.com/janeapp/riffer/issues/75)) ([fcee502](https://github.com/janeapp/riffer/commit/fcee502054882f41d15ea312222a5538c8f04220))

## [0.5.1](https://github.com/janeapp/riffer/compare/riffer/v0.5.0...riffer/v0.5.1) (2026-01-10)


### Bug Fixes

* update Code of Conduct URL in README ([#67](https://github.com/janeapp/riffer/issues/67)) ([39ae1f5](https://github.com/janeapp/riffer/commit/39ae1f5025bcd36e1c5cab76fe8d312179f664ba))
* update gem details to reflect janeapp ownership ([#66](https://github.com/janeapp/riffer/issues/66)) ([06a008d](https://github.com/janeapp/riffer/commit/06a008d5ab050ca2c1afd4163104c6c95c9d248b))
* update GitHub Pages deployment action in release workflow ([#68](https://github.com/janeapp/riffer/issues/68)) ([e2f7961](https://github.com/janeapp/riffer/commit/e2f79616464101d90488f8f28aedcbdf4086277d))

## [0.5.0](https://github.com/janeapp/riffer/compare/riffer/v0.4.2...riffer/v0.5.0) (2026-01-06)

### Features

- streaming via agents ([#63](https://github.com/janeapp/riffer/issues/63)) ([b4171c2](https://github.com/janeapp/riffer/commit/b4171c20f64a7ada1264ce90ab5278c19ff8a47a))

## [0.4.2](https://github.com/janeapp/riffer/compare/riffer/v0.4.1...riffer/v0.4.2) (2025-12-29)

### Bug Fixes

- update README for clarity on provider usage and examples ([#60](https://github.com/janeapp/riffer/issues/60)) ([b12835c](https://github.com/janeapp/riffer/commit/b12835ce71c29e02074a0897551db50283ac8be6))

## [0.4.1](https://github.com/janeapp/riffer/compare/riffer/v0.4.0...riffer/v0.4.1) (2025-12-29)

### Bug Fixes

- add conditional check for docs job execution based on release creation ([#58](https://github.com/janeapp/riffer/issues/58)) ([97bc6f7](https://github.com/janeapp/riffer/commit/97bc6f79b20902f94edac35b7d9d25c2e033d8bd))
- add permissions for contents in docs job ([#57](https://github.com/janeapp/riffer/issues/57)) ([1dd5f7a](https://github.com/janeapp/riffer/commit/1dd5f7a817d4f73c1a0cad1a93fee0148ef10705))
- suppress output during documentation generation ([#53](https://github.com/janeapp/riffer/issues/53)) ([6b7f2d9](https://github.com/janeapp/riffer/commit/6b7f2d9aa7adb5450855097840c971dcf201d8c0))
- update rdoc command to target the lib directory ([#56](https://github.com/janeapp/riffer/issues/56)) ([c319efe](https://github.com/janeapp/riffer/commit/c319efe039ddb118411ad9e270dc0994d3b8cf5c))

## [0.4.0](https://github.com/janeapp/riffer/compare/riffer/v0.3.2...riffer/v0.4.0) (2025-12-29)

### Features

- add documentation generation and publishing workflow ([#51](https://github.com/janeapp/riffer/issues/51)) ([49e3b04](https://github.com/janeapp/riffer/commit/49e3b046c2011f56bb8803b76e152df9ffb26617))

## [0.3.2](https://github.com/janeapp/riffer/compare/riffer/v0.3.1...riffer/v0.3.2) (2025-12-29)

### Bug Fixes

- add Rubygems credentials configuration step in release workflow ([#49](https://github.com/janeapp/riffer/issues/49)) ([dcc71e0](https://github.com/janeapp/riffer/commit/dcc71e01f541510ab73986237adaabfab1ef2401))

## [0.3.1](https://github.com/janeapp/riffer/compare/riffer/v0.3.0...riffer/v0.3.1) (2025-12-29)

### Bug Fixes

- update checkout action version in release workflow ([#47](https://github.com/janeapp/riffer/issues/47)) ([c6b1361](https://github.com/janeapp/riffer/commit/c6b1361b20d7cc4522e20c46fa1a75ad3a8a80d7))

## [0.3.0](https://github.com/janeapp/riffer/compare/riffer-v0.2.0...riffer/v0.3.0) (2025-12-29)

### Features

- add release and publish workflows ([#35](https://github.com/janeapp/riffer/issues/35)) ([3eb0389](https://github.com/janeapp/riffer/commit/3eb03897d0e96c01ef1857c04b2bafa53e37dde0))

### Bug Fixes

- add manifest file to release configuration ([#43](https://github.com/janeapp/riffer/issues/43)) ([8d46135](https://github.com/janeapp/riffer/commit/8d46135ccd1c4315d624fa11a639e51aa1f1e5b8))
- auto-publishing on new release ([#38](https://github.com/janeapp/riffer/issues/38)) ([5a1d267](https://github.com/janeapp/riffer/commit/5a1d267e046c1531e01c80b9e40b94eed216360c))
- remove manifest file from release configuration ([#41](https://github.com/janeapp/riffer/issues/41)) ([2f898d8](https://github.com/janeapp/riffer/commit/2f898d8e1bdf6787583f22c83e83e90f2a75142e))
- remove release-type configuration from release workflow ([#42](https://github.com/janeapp/riffer/issues/42)) ([e270a6c](https://github.com/janeapp/riffer/commit/e270a6c906f7e04f1b0ce57b7d29808c98e7dce8))
- reset release manifest to empty object ([#44](https://github.com/janeapp/riffer/issues/44)) ([26f1b6d](https://github.com/janeapp/riffer/commit/26f1b6d2dcb622295026cc7fb247559156864d74))
- restructure release configuration and update manifest format ([#45](https://github.com/janeapp/riffer/issues/45)) ([d07694c](https://github.com/janeapp/riffer/commit/d07694c05d49166740f3408a343c351d33749edf))
- simplify release configuration by removing unnecessary package structure ([#40](https://github.com/janeapp/riffer/issues/40)) ([8472967](https://github.com/janeapp/riffer/commit/84729670fd202208256e6de69f1b81366ad0a688))

## [0.2.0](https://github.com/janeapp/riffer/compare/v0.1.0...v0.2.0) (2025-12-28)

### Features

- add release and publish workflows ([#35](https://github.com/janeapp/riffer/issues/35)) ([3eb0389](https://github.com/janeapp/riffer/commit/3eb03897d0e96c01ef1857c04b2bafa53e37dde0))

## [0.1.0] - 2024-12-20

### Added

- **Core Framework**: Foundation for building AI-powered applications and agents
- **Configuration System**: Global and instance-level configuration management
- **Agents**: Base agent class for building conversational agents
- **Messages**: Complete message system with support for User, Assistant, System, and Tool messages
- **Providers**: Pluggable provider architecture

  - **OpenAI Provider**: Full integration with OpenAI API for text generation and streaming
  - **Test Provider**: Built-in test provider for development and testing

- **Stream Events**: Streaming response support with TextDelta and TextDone events
- **Zeitwerk Autoloading**: Modern Ruby autoloading for clean code organization
- **Comprehensive Test Suite**: Full RSpec test coverage with VCR cassettes for API mocking
- **StandardRB Code Style**: Enforced code formatting and linting
