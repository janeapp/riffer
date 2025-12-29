# Riffer

The all-in-one Ruby framework for building AI-powered applications and agents.

[![Gem Version](https://badge.fury.io/rb/riffer.svg)](https://badge.fury.io/rb/riffer) [![Build Status](https://github.com/bottrall/riffer/actions/workflows/ci.yml/badge.svg)](https://github.com/bottrall/riffer/actions) ⚠️ Work in progress

## Overview

Riffer is a comprehensive Ruby framework designed to simplify the development of AI-powered applications and agents. It provides a complete toolkit for integrating artificial intelligence capabilities into your Ruby projects.

Key concepts:

- **Agents** – orchestrate messages, LLM calls, and tool execution (`Riffer::Agent`).
- **Providers** – adapters that implement text generation and streaming (`Riffer::Providers::*`).
- **Messages** – typed message objects for system, user, assistant, and tool messages (`Riffer::Messages::*`).

## Features

- Minimal, well-documented core for building AI agents
- Provider abstraction (OpenAI + test provider) for easy testing
- Streaming support and structured stream events
- Message converters and helpers for robust message handling

## Requirements

- Ruby 3.2 or later

## Installation

Install the released gem:

```bash
gem install riffer
```

Or add to your application's Gemfile:

```ruby
gem 'riffer'
```

Install the development branch directly from GitHub:

```ruby
gem 'riffer', git: 'https://github.com/bottrall/riffer.git'
```

## Quick Start

Basic usage with the built-in test provider:

```ruby
require 'riffer'

class EchoAgent < Riffer::Agent
  identifier 'echo'
  model 'test/default' # provider/model
  instructions 'You are an assistant that repeats what the user says.'
end

agent = EchoAgent.new
puts agent.generate('Hello world')
# => "Test response" (the test provider returns a canned response by default)
```

Using the test provider directly (useful for unit tests):

```ruby
provider = Riffer::Providers::Test.new
provider.stub_response('Hello from test provider!')
assistant = provider.generate_text(prompt: 'Say hi')
puts assistant.content # => "Hello from test provider!"
```

Streaming example (provider-dependent):

```ruby
provider = Riffer::Providers::Test.new
enum = provider.stream_text(prompt: 'Stream something')
enum.each do |chunk|
  puts chunk[:content]
end
```

Configuration example (OpenAI API key):

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end
```

## Development

After checking out the repo, run:

```bash
bin/setup
```

Run the test suite:

```bash
bundle exec rake test
```

Check and fix code style:

```bash
bundle exec rake standard
bundle exec rake standard:fix
```

Run the interactive console:

```bash
bin/console
```

## Contributing

1. Fork the repository and create your branch: `git checkout -b feature/foo`
2. Run tests and linters locally: `bundle exec rake`
3. Submit a pull request with a clear description of the change

Please follow the [Code of Conduct](https://github.com/bottrall/riffer/blob/main/CODE_OF_CONDUCT.md).

## Changelog

All notable changes to this project are documented in `CHANGELOG.md`.

## License

Licensed under the MIT License. See `LICENSE.txt` for details.

## Maintainers

- Jake Bottrall — https://github.com/bottrall

---

If you'd like, I can add short usage examples to the documentation site or update the gemspec metadata (authors, homepage, summary).
