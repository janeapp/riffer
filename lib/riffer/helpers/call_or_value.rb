# frozen_string_literal: true
# rbs_inline: enabled

# Resolves the "Proc-or-value" idiom: if +thing+ is a Proc, calls it
# (passing +context+ when its arity is non-zero); otherwise returns
# +thing+ unchanged. When +thing+ is +nil+, returns +default+.
module Riffer::Helpers::CallOrValue
  extend self

  #: (untyped, ?context: untyped, ?default: untyped) -> untyped
  def resolve(thing, context: nil, default: nil)
    return default if thing.nil?
    return thing unless thing.is_a?(Proc)
    thing.arity.zero? ? thing.call : thing.call(context)
  end
end
