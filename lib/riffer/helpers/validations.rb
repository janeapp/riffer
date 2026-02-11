# frozen_string_literal: true
# rbs_inline: enabled

# Helper module for input validation.
module Riffer::Helpers::Validations
  # Validates that a value is a non-empty string.
  #
  # Raises Riffer::ArgumentError if the value is not a string or is empty.
  #
  #: (untyped, ?String) -> true
  def validate_is_string!(value, name = "value")
    raise Riffer::ArgumentError, "#{name} must be a String" unless value.is_a?(String)
    raise Riffer::ArgumentError, "#{name} cannot be empty" if value.strip.empty?

    true
  end
end
