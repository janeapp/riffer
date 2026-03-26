# frozen_string_literal: true
# rbs_inline: enabled

# Processes items concurrently using a thread pool.
#
# Maintains up to +max_concurrency+ worker threads that pull items from
# a shared queue. When a worker finishes one item it immediately picks
# up the next, so a single slow item does not block other workers.
#
# If multiple workers raise, only the first exception is re-raised
# after all workers finish; subsequent errors are discarded.
#
#   runner = Riffer::Runner::Threaded.new(max_concurrency: 3)
#   runner.map(items) { |item| expensive_operation(item) }
#
class Riffer::Runner::Threaded < Riffer::Runner
  DEFAULT_MAX_CONCURRENCY = 5 #: Integer

  # [max_concurrency] maximum number of threads to run simultaneously.
  #
  #--
  #: (?max_concurrency: Integer) -> void
  def initialize(max_concurrency: DEFAULT_MAX_CONCURRENCY)
    @max_concurrency = max_concurrency
  end

  #--
  #: (Array[untyped], context: Hash[Symbol, untyped]?) { (untyped) -> untyped } -> Array[untyped]
  def map(items, context:, &block)
    return [] if items.empty?

    results = Array.new(items.size)
    errors = Array.new(items.size)
    queue = Queue.new
    items.each_with_index { |item, i| queue << [item, i] }

    workers = [items.size, @max_concurrency].min.times.map do
      Thread.new do
        loop do
          pair = begin
            queue.pop(true)
          rescue ThreadError
            break
          end
          item, index = pair
          begin
            results[index] = block.call(item)
          rescue => e
            errors[index] = e
          end
        end
      end
    end

    workers.each(&:join)

    first_error = errors.compact.first
    raise first_error if first_error

    results
  end
end
