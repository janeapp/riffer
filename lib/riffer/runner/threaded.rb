# frozen_string_literal: true
# rbs_inline: enabled

# Processes items concurrently using threads.
#
# Items are executed in batches of +max_concurrency+ threads.
#
#   runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
#   runner.map(items) { |item| expensive_operation(item) }
#
class Riffer::Runner::Threaded < Riffer::Runner
  DEFAULT_MAX_CONCURRENCY = 5 #: Integer

  # +max_concurrency+ - maximum number of threads to run simultaneously.
  #
  #: (?max_concurrency: Integer) -> void
  def initialize(max_concurrency: DEFAULT_MAX_CONCURRENCY)
    @max_concurrency = max_concurrency
  end

  #: (Array[untyped]) { (untyped) -> untyped } -> Array[untyped]
  def map(items, &block)
    items.each_slice(@max_concurrency).flat_map do |batch|
      threads = batch.map { |item| Thread.new { block.call(item) } }
      threads.map(&:value)
    end
  end
end
