# frozen_string_literal: true

# Checks whether a non-strict schema (optional fields left out of +required+
# instead of made nullable) gets past Bedrock native's limits.
#
#   AWS_PROFILE=... bundle exec ruby examples/structured_output_benchmark/probe_non_strict.rb

require "bundler/setup"
require "riffer"
require "aws-sdk-bedrockruntime"

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "clinic"
require "ledger"
require "intake"
require "treatment_plan"
require "grading"
require "tools"
require "chat"
require "scenarios"

client = Aws::BedrockRuntime::Client.new(region: ENV.fetch("AWS_REGION", "us-west-2"))

def flat_optional(count)
  Scenarios.params do
    2.times { |i| required(:"r#{i}", String) }
    count.times { |i| optional(:"o#{i}", String) }
  end
end

cases = {
  "17 optional, non-strict (omitted from required, no null)" => flat_optional(17).to_json_schema(strict: false),
  "30 optional, non-strict" => flat_optional(30).to_json_schema(strict: false),
  "intake, non-strict" => Scenarios.find("intake").schema.to_json_schema(strict: false),
  "intake_xl, non-strict" => Scenarios.find("intake_xl").schema.to_json_schema(strict: false),
}

cases.each do |label, schema|
  client.converse(
    model_id: "us.anthropic.claude-haiku-5-5", messages: [{ role: "user", content: [{ text: "Return the object." }] }],
    inference_config: { max_tokens: 16 },
    output_config: { text_format: { type: "json_schema", structure: { json_schema: { schema: schema.to_json, name: "response" } } } },
  )
  puts "#{label}: ACCEPTED"
rescue Aws::BedrockRuntime::Errors::ServiceError => e
  puts "#{label}: REJECTED #{e.message[0, 200]}"
end
