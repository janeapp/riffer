# frozen_string_literal: true

module Riffer::Helpers::ClassNameConverter
  # Converts a class name to snake_case path format
  # @param class_name [String] the class name (e.g., "Riffer::Agent")
  # @return [String] the snake_case path (e.g., "riffer/agent")
  def class_name_to_path(class_name)
    class_name
      .to_s
      .gsub("::", "/")
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase
  end
end
