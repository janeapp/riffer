# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Runner::Sequential < Riffer::Runner
  #: (Array[untyped]) { (untyped) -> untyped } -> Array[untyped]
  def map(items, &block)
    items.map(&block)
  end
end
