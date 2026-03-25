# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Helpers::ClassNameConverter
  DEFAULT_SEPARATOR = "/" #: String

  #: (String, ?separator: String) -> String
  def class_name_to_path(class_name, separator: DEFAULT_SEPARATOR)
    class_name
      .to_s
      .gsub("::", separator)
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase
  end
end
