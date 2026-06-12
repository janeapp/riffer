# frozen_string_literal: true
# rbs_inline: enabled

# Coercion for boolean-ish configuration values.
module Riffer::Helpers::Boolean
  extend self

  # Coerces +value+ to a boolean so an env-var +"false"+ (truthy in Ruby)
  # doesn't silently read as +true+. Raises Riffer::ArgumentError on an
  # unrecognized value, naming +attribute+ in the message.
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
