# frozen_string_literal: true
# rbs_inline: enabled

# Sentinel type for declaring boolean parameters — Ruby has no +Boolean+ class
# (+true+/+false+ are +TrueClass+/+FalseClass+).
#
#   required :verbose, Riffer::Params::Boolean
#
module Riffer::Params::Boolean
end
