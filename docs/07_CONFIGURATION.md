# Configuration

Riffer uses a centralized configuration system for provider credentials and settings.

## Global Configuration

Use `Riffer.configure` to set up provider credentials:

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
  config.amazon_bedrock.region = 'us-east-1'
  config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end
```

## Accessing Configuration

Access the current configuration via `Riffer.config`:

```ruby
Riffer.config.openai.api_key
# => "sk-..."

Riffer.config.amazon_bedrock.region
# => "us-east-1"

Riffer.config.anthropic.api_key
# => "sk-ant-..."
```

## Provider-Specific Configuration

### OpenAI

| Option    | Description         |
| --------- | ------------------- |
| `api_key` | Your OpenAI API key |

```ruby
Riffer.configure do |config|
  config.openai.api_key = ENV['OPENAI_API_KEY']
end
```

### Amazon Bedrock

| Option      | Description                                  |
| ----------- | -------------------------------------------- |
| `region`    | AWS region (e.g., `us-east-1`)               |
| `api_token` | Optional bearer token for API authentication |

```ruby
Riffer.configure do |config|
  config.amazon_bedrock.region = 'us-east-1'
  config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']  # Optional
end
```

When `api_token` is not set, the provider uses standard AWS IAM authentication.

### Anthropic

| Option    | Description            |
| --------- | ---------------------- |
| `api_key` | Your Anthropic API key |

```ruby
Riffer.configure do |config|
  config.anthropic.api_key = ENV['ANTHROPIC_API_KEY']
end
```

## Agent-Level Configuration

Override global configuration at the agent level:

### provider_options

Pass options directly to the provider client:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'

  # Override API key for this agent only
  provider_options api_key: ENV['CUSTOM_OPENAI_KEY']
end
```

### model_options

Pass options to each LLM request:

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'

  # These options are sent with every generate/stream call
  model_options temperature: 0.7, reasoning: 'medium'
end
```

## Common Model Options

### OpenAI

| Option        | Description                                      |
| ------------- | ------------------------------------------------ |
| `temperature` | Sampling temperature (0.0-2.0)                   |
| `max_tokens`  | Maximum tokens in response                       |
| `top_p`       | Nucleus sampling parameter                       |
| `reasoning`   | Reasoning effort level (`low`, `medium`, `high`) |

```ruby
class MyAgent < Riffer::Agent
  model 'openai/gpt-4o'
  model_options temperature: 0.7, reasoning: 'medium'
end
```

### Amazon Bedrock

| Option        | Description                |
| ------------- | -------------------------- |
| `temperature` | Sampling temperature       |
| `max_tokens`  | Maximum tokens in response |
| `top_p`       | Nucleus sampling parameter |
| `top_k`       | Top-k sampling parameter   |

```ruby
class MyAgent < Riffer::Agent
  model 'amazon_bedrock/anthropic.claude-3-sonnet-20240229-v1:0'
  model_options temperature: 0.7, max_tokens: 4096
end
```

### Anthropic

| Option        | Description                                 |
| ------------- | ------------------------------------------- |
| `temperature` | Sampling temperature                        |
| `max_tokens`  | Maximum tokens in response                  |
| `top_p`       | Nucleus sampling parameter                  |
| `top_k`       | Top-k sampling parameter                    |
| `thinking`    | Extended thinking config hash (Claude 3.7+) |

```ruby
class MyAgent < Riffer::Agent
  model 'anthropic/claude-3-5-sonnet-20241022'
  model_options temperature: 0.7, max_tokens: 4096
end

# With extended thinking (Claude 3.7+)
class ReasoningAgent < Riffer::Agent
  model 'anthropic/claude-3-7-sonnet-20250219'
  model_options thinking: {type: "enabled", budget_tokens: 10000}
end
```

## Environment Variables

Recommended pattern for managing credentials:

```ruby
# config/initializers/riffer.rb (Rails)
# or at application startup

Riffer.configure do |config|
  config.openai.api_key = ENV.fetch('OPENAI_API_KEY') { raise 'OPENAI_API_KEY not set' }

  if ENV['BEDROCK_REGION']
    config.amazon_bedrock.region = ENV['BEDROCK_REGION']
    config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']
  end
end
```

## Multiple Configurations

For different environments or use cases, use agent-level overrides:

```ruby
class ProductionAgent < Riffer::Agent
  model 'openai/gpt-4o'
  provider_options api_key: ENV['PRODUCTION_OPENAI_KEY']
end

class DevelopmentAgent < Riffer::Agent
  model 'openai/gpt-4o-mini'
  provider_options api_key: ENV['DEV_OPENAI_KEY']
  model_options temperature: 0.0  # Deterministic for testing
end
```
