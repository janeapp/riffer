# frozen_string_literal: true

# Sends Riffer-generated strict schemas to Bedrock's native structured output
# and records which ones it accepts. Generation is capped at a few tokens: a
# rejected schema fails before any output, so acceptance is all that matters.
#
#   AWS_PROFILE=... bundle exec ruby examples/structured_output_benchmark/probe_limits.rb --out limits.json

require "bundler/setup"
require "riffer"
require "aws-sdk-bedrockruntime"
require "optparse"

$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "clinic"
require "ledger"
require "intake"
require "treatment_plan"
require "grading"
require "tools"
require "chat"
require "scenarios"

options = { models: %w[us.anthropic.claude-haiku-5-5], region: ENV.fetch("AWS_REGION", "us-west-2"),
            out: "limits.json", }
OptionParser.new do |o|
  o.on("--models LIST", Array) { |v| options[:models] = v }
  o.on("--out PATH") { |v| options[:out] = v }
end.parse!

client = Aws::BedrockRuntime::Client.new(region: options[:region], retry_mode: "adaptive", max_attempts: 8)

def flat(required: 0, optional: 0)
  Scenarios.params do
    required.times { |i| required(:"r#{i}", String) }
    optional.times { |i| optional(:"o#{i}", String) }
  end
end

# Rewrites a JSON schema so every nullable union collapses to its non-null branch.
def without_nulls(node)
  case node
  when Hash
    if node[:type].is_a?(Array)
      node = node.merge(type: (node[:type] - ["null"]).first)
    elsif node[:anyOf]&.any? { |b| b[:type] == "null" }
      rest = node[:anyOf].reject { |b| b[:type] == "null" }
      node = rest.size == 1 ? node.except(:anyOf).merge(rest.first) : node.merge(anyOf: rest)
    end
    node.transform_values { |v| without_nulls(v) }
  when Array then node.map { |v| without_nulls(v) }
  else node
  end
end

def strip_keys(node, keys)
  case node
  when Hash then node.except(*keys).transform_values { |v| strip_keys(v, keys) }
  when Array then node.map { |v| strip_keys(v, keys) }
  else node
  end
end

intake = Scenarios.find("intake").schema.to_json_schema(strict: true)
cases = {
  "16 optional (nullable) fields" => flat(required: 2, optional: 16).to_json_schema(strict: true),
  "17 optional (nullable) fields" => flat(required: 2, optional: 17).to_json_schema(strict: true),
  "60 required strings" => flat(required: 60).to_json_schema(strict: true),
  "70 required strings" => flat(required: 70).to_json_schema(strict: true),
  "80 required strings" => flat(required: 80).to_json_schema(strict: true),
  "90 required strings" => flat(required: 90).to_json_schema(strict: true),
  "100 required strings" => flat(required: 100).to_json_schema(strict: true),
  "150 required strings" => flat(required: 150).to_json_schema(strict: true),
  "200 required strings" => flat(required: 200).to_json_schema(strict: true),
  "intake (as benchmarked)" => intake,
  "intake without format:" => strip_keys(intake, [:format]),
  "intake without enum:" => strip_keys(intake, [:enum]),
  "intake without nullables" => without_nulls(intake),
  "intake without format:, enum:" => strip_keys(intake, %i[format enum]),
  "intake without format:, nullables" => without_nulls(strip_keys(intake, [:format])),
  "intake without format:, enum:, nullables" => without_nulls(strip_keys(intake, %i[format enum])),
}
Scenarios::ALL.each { |s| cases["scenario: #{s.key}"] ||= s.schema.to_json_schema(strict: true) }

def union_count(node)
  case node
  when Hash
    own = node[:type].is_a?(Array) || node.key?(:anyOf) ? 1 : 0
    own + node.values.sum { |v| union_count(v) }
  when Array then node.sum { |v| union_count(v) }
  else 0
  end
end

results = options[:models].flat_map do |model|
  cases.map do |label, schema|
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    client.converse(
      model_id: model, messages: [{ role: "user", content: [{ text: "Return the object." }] }],
      inference_config: { max_tokens: 16 },
      output_config: { text_format: { type: "json_schema", structure: { json_schema: { schema: schema.to_json, name: "response" } } } },
    )
    { model: model, schema: label, accepted: true }
  rescue Aws::BedrockRuntime::Errors::ServiceError => e
    { model: model, schema: label, accepted: false,
      error: e.message.sub("The model returned the following errors: ", "")[0, 240], }
  ensure
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end.map do |r|
    r.merge(schema_bytes: cases[r[:schema]].to_json.bytesize, unions: union_count(cases[r[:schema]]))
  end
end

results.each do |r|
  warn format("%-34s %-46s %-8s unions=%-3d bytes=%-6d %s", r[:model], r[:schema],
              r[:accepted] ? "ACCEPTED" : "REJECTED", r[:unions], r[:schema_bytes], r[:error],)
end
File.write(options[:out], JSON.pretty_generate(results))
