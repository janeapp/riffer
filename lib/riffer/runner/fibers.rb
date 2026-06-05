# frozen_string_literal: true
# rbs_inline: enabled

# Processes items concurrently using fibers via the +async+ gem.
# +max_concurrency+ caps simultaneous fibers via an <tt>Async::Semaphore</tt>.
# If multiple fibers raise, only the first exception is re-raised after all
# finish.
class Riffer::Runner::Fibers < Riffer::Runner
  # @rbs @max_concurrency: Integer?

  #--
  #: (?max_concurrency: Integer?) -> void
  def initialize(max_concurrency: nil)
    depends_on "async"
    depends_on "async/semaphore" if max_concurrency
    @max_concurrency = max_concurrency
  end

  #--
  #: (Array[untyped], context: Riffer::Agent::Context?) { (untyped) -> untyped } -> Array[untyped]
  def map(items, context:, &block)
    return [] if items.empty?

    results = Array.new(items.size)
    errors = Array.new(items.size)

    Async do
      barrier = Async::Barrier.new
      max = @max_concurrency
      parent = if max
        Async::Semaphore.new(max, parent: barrier)
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

  private

  #: (String) -> true
  def depends_on(gem_name)
    Riffer::Helpers::Dependencies.depends_on(gem_name)
  end
end
