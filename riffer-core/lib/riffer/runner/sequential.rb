# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Runner::Sequential < Riffer::Runner
  #--
  #: (Array[untyped], context: Riffer::Agent::Context?) { (untyped) -> untyped } -> Array[untyped]
  def map(items, context:, &)
    items.map(&)
  end
end
