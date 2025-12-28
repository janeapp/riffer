# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1](https://github.com/bottrall/riffer/compare/v0.2.0...v0.2.1) (2025-12-28)


### Bug Fixes

* auto-publishing on new release ([#38](https://github.com/bottrall/riffer/issues/38)) ([5a1d267](https://github.com/bottrall/riffer/commit/5a1d267e046c1531e01c80b9e40b94eed216360c))
* remove manifest file from release configuration ([#41](https://github.com/bottrall/riffer/issues/41)) ([2f898d8](https://github.com/bottrall/riffer/commit/2f898d8e1bdf6787583f22c83e83e90f2a75142e))
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
