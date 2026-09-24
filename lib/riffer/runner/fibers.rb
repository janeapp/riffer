# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Runner::Fibers < Riffer::Runner
  # @rbs @max_concurrency: Integer?

  #--
  #: (?max_concurrency: Integer?) -> void
  def initialize(max_concurrency: nil)
    super()
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

    barrier = Async::Barrier.new
    max = @max_concurrency
    parent = if max
               Async::Semaphore.new(max, parent: barrier)
             else
               barrier
             end

    # Sync joins the running reactor task if there is one, otherwise starts its own.
    Sync do
      items.each_with_index do |item, index|
        parent.async do
          results[index] = yield(item)
        rescue StandardError => e
          errors[index] = e
        end
      end

      barrier.wait
    ensure
      barrier.stop
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
