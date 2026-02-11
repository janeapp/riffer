# frozen_string_literal: true
# rbs_inline: enabled

# Namespace module for guardrail components.
#
# Guardrails provide pre-processing of input messages and post-processing
# of output responses in the agent pipeline.
module Riffer::Guardrails
  PHASES = %i[before after].freeze #: Array[Symbol]
end
