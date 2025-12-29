# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1](https://github.com/bottrall/riffer/compare/riffer/v0.3.0...riffer/v0.3.1) (2025-12-29)


### Bug Fixes

* update checkout action version in release workflow ([#47](https://github.com/bottrall/riffer/issues/47)) ([c6b1361](https://github.com/bottrall/riffer/commit/c6b1361b20d7cc4522e20c46fa1a75ad3a8a80d7))

## [0.3.0](https://github.com/bottrall/riffer/compare/riffer-v0.2.0...riffer/v0.3.0) (2025-12-29)


### Features

* add release and publish workflows ([#35](https://github.com/bottrall/riffer/issues/35)) ([3eb0389](https://github.com/bottrall/riffer/commit/3eb03897d0e96c01ef1857c04b2bafa53e37dde0))


### Bug Fixes

* add manifest file to release configuration ([#43](https://github.com/bottrall/riffer/issues/43)) ([8d46135](https://github.com/bottrall/riffer/commit/8d46135ccd1c4315d624fa11a639e51aa1f1e5b8))
* auto-publishing on new release ([#38](https://github.com/bottrall/riffer/issues/38)) ([5a1d267](https://github.com/bottrall/riffer/commit/5a1d267e046c1531e01c80b9e40b94eed216360c))
* remove manifest file from release configuration ([#41](https://github.com/bottrall/riffer/issues/41)) ([2f898d8](https://github.com/bottrall/riffer/commit/2f898d8e1bdf6787583f22c83e83e90f2a75142e))
* remove release-type configuration from release workflow ([#42](https://github.com/bottrall/riffer/issues/42)) ([e270a6c](https://github.com/bottrall/riffer/commit/e270a6c906f7e04f1b0ce57b7d29808c98e7dce8))
* reset release manifest to empty object ([#44](https://github.com/bottrall/riffer/issues/44)) ([26f1b6d](https://github.com/bottrall/riffer/commit/26f1b6d2dcb622295026cc7fb247559156864d74))
* restructure release configuration and update manifest format ([#45](https://github.com/bottrall/riffer/issues/45)) ([d07694c](https://github.com/bottrall/riffer/commit/d07694c05d49166740f3408a343c351d33749edf))
* simplify release configuration by removing unnecessary package structure ([#40](https://github.com/bottrall/riffer/issues/40)) ([8472967](https://github.com/bottrall/riffer/commit/84729670fd202208256e6de69f1b81366ad0a688))

## [0.2.0](https://github.com/bottrall/riffer/compare/v0.1.0...v0.2.0) (2025-12-28)


### Features

* add release and publish workflows ([#35](https://github.com/bottrall/riffer/issues/35)) ([3eb0389](https://github.com/bottrall/riffer/commit/3eb03897d0e96c01ef1857c04b2bafa53e37dde0))

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
