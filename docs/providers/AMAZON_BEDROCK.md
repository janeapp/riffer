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

`region` resolves in order: `Riffer.config.amazon_bedrock.region` → the AWS SDK's own resolution (`AWS_REGION`, `AWS_DEFAULT_REGION`, shared config). Leaving it unset in riffer defers to the SDK rather than failing.

### Bearer Token Authentication

For API token authentication:

```ruby
Riffer.configure do |config|
  config.amazon_bedrock.region = 'us-east-1'
  config.amazon_bedrock.api_token = ENV['BEDROCK_API_TOKEN']
end
```

### Custom client

AWS auth beyond the bearer token or default credential chain (profiles, STS, IRSA), plus retries, timeouts, and endpoints, is configured on your own `Aws::BedrockRuntime::Client`:

```ruby
Riffer.configure do |config|
  config.amazon_bedrock.client = Aws::BedrockRuntime::Client.new(
    region: 'us-east-1',
    credentials: Aws::AssumeRoleCredentials.new(role_arn: ENV['BEDROCK_ROLE_ARN'], role_session_name: 'riffer'),
    retry_limit: 5
  )
end
```

The setting accepts a client instance or a no-argument `Proc`, resolved on every LLM call — see [Configuration → Provider Clients](../CONFIGURATION.md#provider-clients).

## Supported Models

Use Bedrock model IDs in the `amazon_bedrock/model` format:

```ruby
# Claude models
model 'amazon_bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0'
model 'amazon_bedrock/us.anthropic.claude-sonnet-4-5-20250929-v1:0'
model 'amazon_bedrock/us.anthropic.claude-opus-4-5-20251101-v1:0'

# Other foundation models available in Bedrock
model 'amazon_bedrock/amazon.titan-text-express-v1'
```

## Model Options

Options are passed through to the [Bedrock Converse API](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/BedrockRuntime/Client.html#converse-instance_method). Use the nested structures the API expects.

### inference_config

Controls generation parameters:

```ruby
model_options inference_config: {
  max_tokens: 4096,
  temperature: 0.7,
  top_p: 0.95,
  stop_sequences: ["\n\nHuman:"]
}
```

### additional_model_request_fields

Model-specific parameters (e.g., `top_k` for Claude):

```ruby
model_options additional_model_request_fields: {
  top_k: 250
}
```

### cache_control

Enable prompt caching for models that support it (Claude, Nova). Riffer appends a single Converse `cachePoint` to the stable prefix — after the system array, or after the tools when there is no system prompt — so system instructions and tool definitions are reused across the calls in an agent loop and across conversation turns. The volatile message tail is never cached.

```ruby
# 5-minute TTL (default)
model_options cache_control: {type: "ephemeral"}

# 1-hour TTL (model-dependent; Bedrock validates support)
model_options cache_control: {type: "ephemeral", ttl: "1h"}
```

Caching is opt-in: omit `cache_control` and no cachePoint is sent. The breakpoint is only honored once the prefix clears the model's minimum token count; on models that don't support `cachePoint`, the Converse request errors. Verify hits via `response.token_usage.cache_read_tokens`.

## Example

```ruby
Riffer.configure do |config|
  config.amazon_bedrock.region = 'us-east-1'
end

class AssistantAgent < Riffer::Agent
  model 'amazon_bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0'
  instructions 'You are a helpful assistant.'
  model_options inference_config: {temperature: 0.7, max_tokens: 4096}
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
    text("Found 10 objects in #{bucket}")
  end
end

class AWSAgent < Riffer::Agent
  model 'amazon_bedrock/us.anthropic.claude-haiku-4-5-20251001-v1:0'
  uses_tools [S3ListTool]
end
```

## File Support

Bedrock accepts file attachments either as base64-encoded data, or as `s3://` URIs passed straight through to Converse — Bedrock fetches the S3 object itself:

```ruby
file = Riffer::Messages::FilePart.from_url("s3://my-bucket/document.pdf", media_type: "application/pdf")
response = provider.generate_text(
  prompt: "Summarize this document",
  model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
  files: [file]
)
```

Any other URL scheme (e.g. `https://`) isn't something Bedrock accepts as a reference, so riffer downloads the file itself and sends it as base64 — see [File Downloads](../CONFIGURATION.md#file-downloads) for the `allow_downloads` policy this requires.

**A `sha256:` on an `s3://` `FilePart` is a combination that always fails with the default setup.** Setting `sha256:` forces riffer to download and verify the file itself before Bedrock ever sees it, regardless of the URL scheme — but riffer's default downloader only fetches `https://` URLs, so an `s3://` source can never be verified out of the box. Either configure a custom `Riffer.config.files.downloader` that can reach S3, or omit `sha256:` and let the `s3://` URI pass straight through to Bedrock unverified.

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
provider = Riffer::Providers::AmazonBedrock.new

response = provider.generate_text(
  prompt: "Hello!",
  model: "us.anthropic.claude-haiku-4-5-20251001-v1:0",
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
