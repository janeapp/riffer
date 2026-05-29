# frozen_string_literal: true
# rbs_inline: enabled

# Riffer::Params::Boolean is a sentinel type for declaring boolean parameters.
#
# Ruby has no +Boolean+ class (+true+ is +TrueClass+, +false+ is +FalseClass+).
# Use this module wherever you need a single type that means "boolean":
#
#   required :verbose, Riffer::Params::Boolean
#
module Riffer::Params::Boolean
end
