# frozen_string_literal: true
# rbs_inline: enabled

class Riffer::Runner
  #--
  #: (Array[untyped], context: Riffer::Agent::Context?) { (untyped) -> untyped } -> Array[untyped]
  def map(items, context:, &block)
    raise NotImplementedError, "#{self.class} must implement #map"
  end
end
