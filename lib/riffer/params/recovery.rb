# frozen_string_literal: true
# rbs_inline: enabled

require "json"

# Recovers an argument whose container shape the model got wrong.
#
# A model asked for an array param sometimes writes the array as a JSON *string* — the
# right data in the wrong container. Without recovery the call is rejected outright, before
# the tool body runs, and the whole turn is wasted on a shape mistake.
#
# This mirrors the intent already encoded in Riffer::Params#coerce_value for Float: a
# caller should not get a type that depends on how the model happened to write the value.
#
# Only a value that decodes to the declared type is recovered. A payload that decodes to
# something else, prose, or a truncated fragment is returned untouched and still fails
# validation — the intent there is ambiguous, and a tool acting on a guess is worse than a
# tool reporting the error.
module Riffer::Params::Recovery
  extend self

  # Returns the recovered value, or +value+ unchanged when it cannot be recovered.
  #--
  #: (Riffer::Params::Param, untyped) -> untyped
  def call(param, value)
    return value unless param.type == Array && value.is_a?(String)

    decoded = parse(value)
    decoded.is_a?(Array) ? decoded : value
  end

  private

  # symbolize_names matches how tool-call arguments are parsed before they reach
  # validation, so a decoded item's keys line up with the nested param names.
  #--
  #: (String) -> untyped
  def parse(json)
    JSON.parse(json, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end
end
