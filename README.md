# Riffer

TODO: Delete this and the text below, and describe your gem

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/riffer`. To experiment with that code, run `bin/console` for an interactive prompt.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

### Creating Tools

Riffer provides a simple DSL for creating tools that can be used by AI agents. Tools encapsulate functionality that the LLM can invoke during conversations.

```ruby
class GetWeather < Riffer::Tool
  id "get_weather"
  description "Get the current weather in a given location"
  
  parameters({
    type: "object",
    properties: {
      location: { 
        type: "string", 
        description: "The city and state, e.g. San Francisco, CA" 
      },
      unit: { 
        type: "string", 
        enum: ["celsius", "fahrenheit"] 
      }
    },
    required: ["location"]
  })

  def execute(location:, unit: "celsius")
    # Your tool logic here
    # This is a simple example - in practice, you'd call a weather API
    "Weather in #{location}: 72°#{unit == "celsius" ? "C" : "F"}, sunny"
  end
end
```

### Creating Agents with Tools

Once you've defined your tools, you can register them with an agent:

```ruby
class WeatherAgent < Riffer::Agent
  model "openai/gpt-4o"
  instructions "You are a helpful weather assistant."
  tool GetWeather
end

# Configure your provider
Riffer.configure do |config|
  config.openai.api_key = ENV["OPENAI_API_KEY"]
end

# Use the agent
agent = WeatherAgent.new
response = agent.generate("What's the weather in San Francisco?")
puts response
```

The agent will automatically:
1. Send the tool definitions to the LLM
2. Detect when the LLM wants to call a tool
3. Execute the appropriate tool with the provided arguments
4. Send the tool results back to the LLM
5. Return the final response

### Multiple Tools

Agents can register multiple tools:

```ruby
class Calculator < Riffer::Tool
  id "calculator"
  description "Perform basic arithmetic operations"
  
  parameters({
    type: "object",
    properties: {
      operation: { 
        type: "string", 
        enum: ["add", "subtract", "multiply", "divide"] 
      },
      a: { type: "number" },
      b: { type: "number" }
    },
    required: ["operation", "a", "b"]
  })

  def execute(operation:, a:, b:)
    result = case operation
    when "add" then a + b
    when "subtract" then a - b
    when "multiply" then a * b
    when "divide" then a / b
    end
    
    "#{a} #{operation} #{b} = #{result}"
  end
end

class AssistantAgent < Riffer::Agent
  model "openai/gpt-4o"
  instructions "You are a helpful assistant with access to various tools."
  tool GetWeather
  tool Calculator
end
```

### Tool Parameters

The `parameters` method accepts a JSON Schema object that defines the structure of arguments your tool expects. This schema is used by:
- The LLM to understand what arguments to provide
- The framework to validate and route tool calls
- Your code documentation

The `execute` method signature should match the properties defined in your parameters schema.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/riffer. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/riffer/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Riffer project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/riffer/blob/main/CODE_OF_CONDUCT.md).
