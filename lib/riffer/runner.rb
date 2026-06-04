# frozen_string_literal: true
# rbs_inline: enabled

# Generic concurrency primitive for batch execution. Subclasses implement
# +map+ to control how items are processed.
class Riffer::Runner
  # Maps over items using the provided block.
  #--
  #: (Array[untyped], context: Riffer::Agent::Context?) { (untyped) -> untyped } -> Array[untyped]
  def map(items, context:, &block)
    raise NotImplementedError, "#{self.class} must implement #map"
  end
end
