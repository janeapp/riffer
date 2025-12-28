# frozen_string_literal: true

module Riffer::Helpers::Validations
  def validate_is_string!(value, name = "value")
    raise Riffer::ArgumentError, "#{name} must be a String" unless value.is_a?(String)
    raise Riffer::ArgumentError, "#{name} cannot be empty" if value.strip.empty?

    true
  end
end
