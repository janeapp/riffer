# frozen_string_literal: true
# rbs_inline: enabled

# Memoized snake_case identifier derivation from the host class name.
module Riffer::Helpers::DerivedIdentifier # :nodoc: all
  # @rbs @derived_identifier: String?

  #--
  #: () -> String
  def derived_identifier
    memoized = @derived_identifier
    return memoized if memoized

    # A plain +name+ call can be shadowed by a host DSL method (Toolable's
    # +name+ delegates to +identifier+, which would recurse), so the original
    # Module#name is bound explicitly.
    class_name = Module.instance_method(:name).bind_call(self)
    # An anonymous class gets its real name once assigned to a constant, so a
    # nil-name derivation is never cached.
    return "" unless class_name

    @derived_identifier = Riffer::Helpers::ClassNameConverter.convert(class_name)
  end
end
