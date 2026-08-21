# frozen_string_literal: true
# rbs_inline: enabled

# Helper module for deriving snake_case identifiers from class names.
module Riffer::Helpers::Identifier
  extend self

  # Derives a snake_case identifier from a class name string.
  #
  #--
  #: (String?) -> String
  def derive(class_name)
    class_name.
      to_s.
      gsub("::", "/").
      gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
      gsub(/([a-z\d])([A-Z])/, '\1_\2').
      downcase
  end

  # Derives and memoizes the identifier for a class or module. Anonymous
  # classes return "" without caching, so a class named later still derives its
  # real identifier.
  #
  #--
  #: (Module) -> String
  def for(klass)
    cached = klass.instance_variable_get(:@derived_identifier) #: String?
    return cached if cached

    # Tool classes shadow Module#name with the identifier DSL, so the real
    # class-path name must come from Module's own implementation.
    real_name = Module.instance_method(:name).bind_call(klass) #: String?
    return "" if real_name.nil?

    derived = derive(real_name)
    klass.instance_variable_set(:@derived_identifier, derived)
    derived
  end
end
