# frozen_string_literal: true
# rbs_inline: enabled

# Namespace for guardrail components that pre-process input and post-process
# output in the agent pipeline.
module Riffer::Guardrails
  PHASES = %i[before after].freeze #: Array[Symbol]
end
