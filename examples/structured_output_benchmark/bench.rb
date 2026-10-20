# frozen_string_literal: true

# Benchmarks Riffer's :prompted structured-output strategy against Bedrock's
# native constrained decoding (:native) on Claude models.
#
#   AWS_PROFILE=... bundle exec ruby examples/structured_output_benchmark/bench.rb \
#     --models us.anthropic.claude-sonnet-5-5 --reps 5 --concurrency 6 --out results.jsonl
#
# Each finished run is appended to --out as one JSON line, so an interrupted
# benchmark can be resumed with --resume.

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
require "harness"

options = {
  models: %w[us.anthropic.claude-opus-5-5 us.anthropic.claude-sonnet-5-5 us.anthropic.claude-haiku-5-5],
  strategies: %w[native prompted],
  scenarios: Scenarios::ALL.map(&:key),
  reps: 5,
  concurrency: 6,
  region: ENV.fetch("AWS_REGION", "us-west-2"),
  out: "structured_output_benchmark.jsonl",
  resume: false,
}

OptionParser.new do |o|
  o.on("--models LIST", Array) { |v| options[:models] = v }
  o.on("--strategies LIST", Array) { |v| options[:strategies] = v }
  o.on("--scenarios LIST", Array) { |v| options[:scenarios] = v }
  o.on("--reps N", Integer) { |v| options[:reps] = v }
  o.on("--concurrency N", Integer) { |v| options[:concurrency] = v }
  o.on("--region REGION") { |v| options[:region] = v }
  o.on("--out PATH") { |v| options[:out] = v }
  o.on("--resume") { options[:resume] = true }
end.parse!

Riffer.config.amazon_bedrock.client = Aws::BedrockRuntime::Client.new(
  region: options[:region], retry_mode: "adaptive", max_attempts: 8, http_read_timeout: 600,
)
provider_factory = -> { Riffer::Providers::AmazonBedrock.new }

done = if options[:resume] && File.exist?(options[:out])
         File.readlines(options[:out]).to_set { |l| JSON.parse(l).values_at("model", "strategy", "scenario", "rep") }
       else
         Set.new
       end

jobs = (0...options[:reps]).flat_map do |rep|
  options[:models].product(options[:scenarios], options[:strategies]).map do |model, scenario, strategy|
    { model: model, scenario: scenario, strategy: strategy, rep: rep }
  end
end
jobs.reject! { |j| done.include?(j.values_at(:model, :strategy, :scenario, :rep)) }
# Rep 0 runs first so it captures each schema's first (grammar-compiling) request;
# the rest are shuffled so neither strategy systematically runs at a quieter time.
first, rest = jobs.partition { |j| j[:rep].zero? }
queue = Queue.new
(first.shuffle(random: Random.new(1)) + rest.shuffle(random: Random.new(2))).each { |j| queue << j }
total = queue.size
finished = 0
lock = Mutex.new

warn "Running #{total} runs (#{options[:models].size} models × #{options[:scenarios].size} scenarios × " \
     "#{options[:strategies].size} strategies × #{options[:reps]} reps) with concurrency #{options[:concurrency]}"

workers = Array.new(options[:concurrency]) do
  Thread.new do
    loop do
      job = queue.pop(true)
      scenario = Scenarios.find(job[:scenario])
      record = Harness.run(scenario: scenario, model: job[:model], strategy: job[:strategy].to_sym,
                           provider_factory: provider_factory,)
      line = job.merge(finished_at: Time.now.utc.iso8601).merge(record)
      lock.synchronize do
        File.open(options[:out], "a") { |f| f.puts(JSON.generate(line)) }
        finished += 1
        grade = record[:grade] ? "#{record[:grade][:correct]}/#{record[:grade][:total]} fab=#{record[:grade][:fabricated]}" : "-"
        warn format("[%3d/%d] %-32s %-17s %-8s rep%-2d %-16s %6.1fs ttft=%-5s tools=%-2d %s",
                    finished, total, job[:model], job[:scenario], job[:strategy], job[:rep], record[:status], record[:total_s].to_f,
                    record[:ttft_s]&.round(2), record[:tool_calls]&.size.to_i, grade,)
      end
    rescue ThreadError
      break
    end
  end
end
workers.each(&:join)
