# frozen_string_literal: true

# Helper module for input validation.
module Riffer::Helpers::Validations
  # Validates that a value is a non-empty string.
  #
  # value:: Object - the value to validate
  # name:: String - the name of the value for error messages
  #
  # Returns true if valid.
  #
  # Raises Riffer::ArgumentError if the value is not a string or is empty.
  def validate_is_string!(value, name = "value")
    raise Riffer::ArgumentError, "#{name} must be a String" unless value.is_a?(String)
    raise Riffer::ArgumentError, "#{name} cannot be empty" if value.strip.empty?

    true
  end
end
