# frozen_string_literal: true
# rbs_inline: enabled

# Namespace for LLM provider adapters in the Riffer framework.
#
# Providers connect Riffer to LLM services:
# - Riffer::Providers::OpenAI - OpenAI GPT models
# - Riffer::Providers::AzureOpenAI - Azure OpenAI GPT models
# - Riffer::Providers::AmazonBedrock - AWS Bedrock models
# - Riffer::Providers::OpenRouter - OpenRouter unified gateway
# - Riffer::Providers::Mock - Mock provider for testing
module Riffer::Providers
end
