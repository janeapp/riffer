# frozen_string_literal: true
# rbs_inline: enabled

# Processes items sequentially in the current thread.
#
# This is the default runner used when no concurrency is needed.
#
class Riffer::Runner::Sequential < Riffer::Runner
  #--
  #: (Array[untyped], context: Riffer::Agent::Context?) { (untyped) -> untyped } -> Array[untyped]
  def map(items, context:, &block)
    items.map(&block)
  end
end
