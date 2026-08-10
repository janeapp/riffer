# frozen_string_literal: true
# rbs_inline: enabled

# Resolves the Proc-or-value idiom.
module Riffer::Helpers::CallOrValue
  extend self

  # Calls +thing+ when it's a Proc (passing +context+ if its arity is non-zero),
  # returns it unchanged otherwise, or +default+ when +nil+.
  #--
  #: (untyped, ?context: untyped, ?default: untyped) -> untyped
  def resolve(thing, context: nil, default: nil)
    return default if thing.nil?
    return thing unless thing.is_a?(Proc)

    thing.arity.zero? ? thing.call : thing.call(context)
  end
end
