# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
