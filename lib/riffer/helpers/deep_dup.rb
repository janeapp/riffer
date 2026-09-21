# frozen_string_literal: true
# rbs_inline: enabled

# Copying for the nested Hashes and Arrays a configuration object holds.
module Riffer::Helpers::DeepDup
  extend self

  # Returns +value+ with every Hash and Array rebuilt, so a copy shares no
  # collection with its source.
  #
  # Anything else is returned as-is, which a Class or a Proc needs: +Class#dup+
  # answers a new anonymous class. One source collection maps to one copy, so
  # references shared within +value+ stay shared in the result — an +:around+
  # guardrail registered under two phases is still one registration afterwards.
  #--
  #: (untyped) -> untyped
  def call(value)
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
    else value
    end
  end
end
