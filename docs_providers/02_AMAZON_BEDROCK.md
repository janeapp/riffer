# Amazon Bedrock Provider

The Amazon Bedrock provider connects to AWS Bedrock for Claude and other foundation models.

## Installation

Add the AWS SDK gem to your Gemfile:

```ruby
gem 'aws-sdk-bedrockruntime'
```

## Configuration

### IAM Authentication (Recommended)

Configure your AWS credentials using standard AWS methods (environment variables, IAM roles, etc.):

```ruby
Riffer.configure do |config|
  config.amazon_bedrock.region = 'us-east-1'
end
```

### Bearer Token Authentication

For API token authentication:

```ruby
Riffer.configure do |config|
  config.amazon_bedrock.region = 'us-east-1'
  config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']
end
```

Or per-agent:

```ruby
class MyAgent < Riffer::Agent
  model 'amazon_bedrock/anthropic.claude-3-sonnet-20240229-v1:0'
  provider_options region: 'us-west-2', api_token: ENV['BEDROCK_API_TOKEN']
end
```

## Supported Models

Use Bedrock model IDs in the `amazon_bedrock/model` format:

```ruby
# Claude models
model 'amazon_bedrock/anthropic.claude-3-opus-20240229-v1:0'
model 'amazon_bedrock/anthropic.claude-3-sonnet-20240229-v1:0'
model 'amazon_bedrock/anthropic.claude-3-haiku-20240307-v1:0'

# Other foundation models available in Bedrock
model 'amazon_bedrock/amazon.titan-text-express-v1'
```

## Model Options

### temperature

Controls randomness:

```ruby
model_options temperature: 0.7
```

### max_tokens

Maximum tokens in response:

```ruby
model_options max_tokens: 4096
```

### top_p

Nucleus sampling parameter:

```ruby
model_options top_p: 0.95
```

### top_k

Top-k sampling parameter:

```ruby
model_options top_k: 250
```

## Example

```ruby
Riffer.configure do |config|
  config.amazon_bedrock.region = 'us-east-1'
end

class AssistantAgent < Riffer::Agent
  model 'amazon_bedrock/anthropic.claude-3-sonnet-20240229-v1:0'
  instructions 'You are a helpful assistant.'
  model_options temperature: 0.7, max_tokens: 4096
end

agent = AssistantAgent.new
puts agent.generate("Explain cloud computing")
```

## Streaming

```ruby
agent.stream("Tell me about AWS services").each do |event|
  case event
  when Riffer::StreamEvents::TextDelta
    print event.content
  when Riffer::StreamEvents::TextDone
    puts "\n[Complete]"
  when Riffer::StreamEvents::ToolCallDone
    puts "[Tool: #{event.name}]"
  end
end
```

## Tool Calling

Bedrock provider converts tools to the Bedrock tool_config format:

```ruby
class S3ListTool < Riffer::Tool
  description "Lists objects in an S3 bucket"

  params do
    required :bucket, String, description: "The S3 bucket name"
    optional :prefix, String, description: "Object prefix filter"
  end

  def call(context:, bucket:, prefix: nil)
    # Implementation
    "Found 10 objects in #{bucket}"
  end
end

class AWSAgent < Riffer::Agent
  model 'amazon_bedrock/anthropic.claude-3-sonnet-20240229-v1:0'
  uses_tools [S3ListTool]
end
```

## Message Format

The provider converts Riffer messages to Bedrock format:

| Riffer Message | Bedrock Format                                  |
| -------------- | ----------------------------------------------- |
| `System`       | Added to `system` array as `{text: ...}`        |
| `User`         | `{role: "user", content: [{text: ...}]}`        |
| `Assistant`    | `{role: "assistant", content: [...]}`           |
| `Tool`         | `{role: "user", content: [{tool_result: ...}]}` |

## Direct Provider Usage

```ruby
provider = Riffer::Providers::AmazonBedrock.new(
  region: 'us-east-1',
  api_token: ENV['BEDROCK_API_TOKEN']  # Optional
)

response = provider.generate_text(
  prompt: "Hello!",
  model: "anthropic.claude-3-sonnet-20240229-v1:0",
  temperature: 0.7
)

puts response.content
```

## AWS IAM Permissions

Ensure your IAM role/user has the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:*::foundation-model/*"
    }
  ]
}
```
