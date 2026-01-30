# frozen_string_literal: true

# Helper module for converting class names.
module Riffer::Helpers::ClassNameConverter
  DEFAULT_SEPARATOR = "/"

  # Converts a class name to snake_case identifier format.
  #
  # class_name:: String - the class name (e.g., "Riffer::Agent")
  # separator:: String - the separator to use for namespaces (default: "/")
  #
  # Returns String - the snake_case identifier (e.g., "riffer/agent").
  def class_name_to_path(class_name, separator: DEFAULT_SEPARATOR)
    class_name
      .to_s
      .gsub("::", separator)
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase
  end
end
