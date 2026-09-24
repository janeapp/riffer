# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Helpers::Boolean
  extend self

  #--
  #: (untyped, attribute: String) -> bool
  def coerce(value, attribute:)
    case value
    when true, "true", 1, "1" then true
    when false, "false", 0, "0", nil then false
    else
      raise Riffer::ArgumentError,
            "#{attribute} must be a boolean (or 'true'/'false'/'1'/'0'/1/0), got #{value.inspect}"
    end
  end
end
