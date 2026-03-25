# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Runner::Threaded < Riffer::Runner
  DEFAULT_MAX_CONCURRENCY = 5 #: Integer

  #: (?max_concurrency: Integer) -> void
  def initialize(max_concurrency: DEFAULT_MAX_CONCURRENCY)
    @max_concurrency = max_concurrency
  end

  #: (Array[untyped]) { (untyped) -> untyped } -> Array[untyped]
  def map(items, &block)
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
