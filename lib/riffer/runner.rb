# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Runner
  #: (Array[untyped]) { (untyped) -> untyped } -> Array[untyped]
  def map(items, &block)
    raise NotImplementedError, "#{self.class} must implement #map"
  end
end
