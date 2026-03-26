# frozen_string_literal: true
# rbs_inline: enabled

# Processes items concurrently using fibers via the +async+ gem.
#
# All items run as fibers simultaneously by default. When
# +max_concurrency+ is set, an <tt>Async::Semaphore</tt> limits how many
# fibers execute at once.
#
# If multiple fibers raise, only the first exception is re-raised
# after all fibers finish; subsequent errors are discarded.
#
#   runner = Riffer::Runner::Fibers.new
#   runner.map(items) { |item| expensive_operation(item) }
#
class Riffer::Runner::Fibers < Riffer::Runner
  include Riffer::Helpers::Dependencies

  # [max_concurrency] maximum number of fibers to run simultaneously.
  #   When +nil+, all fibers run without limit.
  #
  #--
  #: (?max_concurrency: Integer?) -> void
  def initialize(max_concurrency: nil)
    depends_on "async"
    depends_on "async/semaphore" if max_concurrency
    @max_concurrency = max_concurrency
  end

  #--
  #: (Array[untyped], context: Hash[Symbol, untyped]?) { (untyped) -> untyped } -> Array[untyped]
  def map(items, context:, &block)
    return [] if items.empty?

    results = Array.new(items.size)
    errors = Array.new(items.size)

    Async do
      barrier = Async::Barrier.new
      parent = if @max_concurrency
        Async::Semaphore.new(@max_concurrency, parent: barrier)
      else
        barrier
      end

      items.each_with_index do |item, index|
        parent.async do
          results[index] = block.call(item)
        rescue => e
          errors[index] = e
        end
      end

      barrier.wait
    end

    first_error = errors.compact.first
    raise first_error if first_error

    results
  end
end
