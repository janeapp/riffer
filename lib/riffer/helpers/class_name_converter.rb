# frozen_string_literal: true
# rbs_inline: enabled

# Helper module for converting class names.
module Riffer::Helpers::ClassNameConverter
  extend self

  DEFAULT_SEPARATOR = "/" #: String

  # Converts a class name to snake_case identifier format. Nil passes through
  # so +||=+ memoization at call sites never caches the identifier of a
  # still-anonymous class (it derives once the class is assigned to a constant).
  #
  #--
  #: (String, ?separator: String) -> String
  #: (nil, ?separator: String) -> nil
  #: (String?, ?separator: String) -> String?
  def convert(class_name, separator: DEFAULT_SEPARATOR)
    return if class_name.nil?

    class_name.
      to_s.
      gsub("::", separator).
      gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
      gsub(/([a-z\d])([A-Z])/, '\1_\2').
      downcase
  end
end
