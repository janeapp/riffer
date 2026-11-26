# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Helpers::Identifier
  extend self

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

  #--
  #: (Module) -> String
  def for(klass)
    cached = klass.instance_variable_get(:@derived_identifier) #: String?
    return cached if cached

    real_name = real_name(klass)
    # Anonymous classes skip the cache so a class named later still derives its
    # real identifier; callers must not memoize their own for the same reason.
    return "" if real_name.nil?

    derived = derive(real_name)
    klass.instance_variable_set(:@derived_identifier, derived)
    derived
  end

  #--
  #: (Module) -> String?
  def real_name(klass)
    # Tool classes shadow Module#name with the identifier DSL.
    Module.instance_method(:name).bind_call(klass) #: String?
  end
end
