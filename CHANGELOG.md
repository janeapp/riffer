# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
