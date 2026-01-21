# Riffer

The all-in-one Ruby framework for building AI-powered applications and agents.

[![Gem Version](https://badge.fury.io/rb/riffer.svg)](https://badge.fury.io/rb/riffer) ⚠️ Work in progress

## Overview

Riffer is a comprehensive Ruby framework designed to simplify the development of AI-powered applications and agents. It provides a complete toolkit for integrating artificial intelligence capabilities into your Ruby projects.

Key concepts:

- **Agents** – orchestrate messages, LLM calls, and tool execution (`Riffer::Agent`).
- **Tools** – define callable functions that agents can use to interact with external systems (`Riffer::Tool`).
- **Providers** – adapters that implement text generation and streaming (`Riffer::Providers::*`).
- **Messages** – typed message objects for system, user, assistant, and tool messages (`Riffer::Messages::*`).

## Features

- Minimal, well-documented core for building AI agents
- Tool calling support with parameter validation
- Provider abstraction (OpenAI, Amazon Bedrock) for pluggable providers
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
gem 'riffer', git: 'https://github.com/janeapp/riffer.git'
```

## Quick Start

Basic usage with the OpenAI provider:

```ruby
require 'riffer'

# Configure OpenAI API key (recommended to use ENV)
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end

class EchoAgent < Riffer::Agent
  model 'openai/gpt-5-mini' # provider/model
  instructions 'You are an assistant that repeats what the user says.'
end

agent = EchoAgent.new
puts agent.generate('Hello world')
# => "Hello world"
```

Streaming example:

```ruby
agent = EchoAgent.new
agent.stream('Tell me a story').each do |event|
  print event.content
end
```

### Provider & Model Options

Agents support two optional configuration methods for passing options through to the underlying provider:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  instructions 'You are a helpful assistant.'

  # Options passed directly to the provider client (e.g., OpenAI::Client)
  provider_options api_key: ENV['CUSTOM_OPENAI_KEY']

  # Options passed to the model invocation (e.g., reasoning, temperature)
  model_options reasoning: 'medium'
end
```

- `provider_options` - Hash of options passed to the provider client during instantiation
- `model_options` - Hash of options passed to `generate_text` / `stream_text` calls

### Tools

Tools allow agents to interact with external systems. Define a tool by extending `Riffer::Tool`:

```ruby
class WeatherLookupTool < Riffer::Tool
  description "Provides current weather information for a specified city."

  params do
    required :city, String, description: "The city to look up"
    optional :units, String, default: "celsius", enum: ["celsius", "fahrenheit"]
  end

  def call(context:, city:, units: nil)
    weather = WeatherService.lookup(city, units: units || "celsius")
    "The weather in #{city} is #{weather.temperature} #{units}."
  end
end
```

Register tools with an agent using `uses_tools`:

```ruby
class WeatherAgent < Riffer::Agent
  model 'openai/gpt-4o'
  instructions 'You are a helpful weather assistant.'

  uses_tools [WeatherLookupTool]
end

agent = WeatherAgent.new
puts agent.generate("What's the weather in Toronto?")
```

Tools can also be dynamically resolved at runtime. The lambda receives `tool_context` when it accepts a parameter, enabling conditional tool resolution based on the current user or request:

```ruby
class DynamicAgent < Riffer::Agent
  model 'openai/gpt-4o'

  uses_tools ->(context) {
    tools = [WeatherLookupTool]
    tools << AdminTool if context&.dig(:current_user)&.admin?
    tools
  }
end

agent = DynamicAgent.new
agent.generate("Do admin things", tool_context: { current_user: current_user })
```

Pass context to tools using `tool_context`:

```ruby
agent.generate("Look up my city", tool_context: { user_id: current_user.id })
```

The `context` keyword argument is passed to every tool's `call` method, allowing tools to access shared state like user information, database connections, or API clients.

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

Please follow the [Code of Conduct](https://github.com/janeapp/riffer/blob/main/CODE_OF_CONDUCT.md).

## Changelog

All notable changes to this project are documented in `CHANGELOG.md`.

## License

Licensed under the MIT License. See `LICENSE.txt` for details.

## Maintainers

- Jake Bottrall — https://github.com/bottrall
