# frozen_string_literal: true
# rbs_inline: enabled

module Riffer::Helpers::DeepDup
  extend self

  #--
  #: (untyped) -> untyped
  def call(value)
    # References shared within +value+ stay shared in the copy — an +:around+
    # guardrail registered under two phases is still one registration.
    seen = {} #: Hash[untyped, untyped]

    rebuild(value, seen.compare_by_identity)
  end

  private

  #--
  #: (untyped, Hash[untyped, untyped]) -> untyped
  def rebuild(value, seen)
    return seen[value] if seen.key?(value)

    case value
    when Hash
      copy = seen[value] = {}
      value.each { |key, entry| copy[key] = rebuild(entry, seen) }
      copy
    when Array
      copy = seen[value] = []
      value.each { |entry| copy << rebuild(entry, seen) }
      copy
    # Class#dup answers a new anonymous class, so non-collections stay as-is.
    else value
    end
  end
end
