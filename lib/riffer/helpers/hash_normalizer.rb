# frozen_string_literal: true
# rbs_inline: enabled

# Helper for normalizing hash keys after deserialization.
#
# JSON.parse without +symbolize_names: true+ produces string-keyed
# hashes; the +from_h+ / +from_config+ entry points use this to accept
# either form transparently.
module Riffer::Helpers::HashNormalizer
  module_function

  # Recursively converts hash keys to symbols.
  #
  #--
  #: (untyped) -> untyped
  def deep_symbolize_keys(value)
    case value
    when Hash
      value.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize_keys(v) }
    when Array
      value.map { |v| deep_symbolize_keys(v) }
    else
      value
    end
  end
end
