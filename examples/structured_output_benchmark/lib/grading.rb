# frozen_string_literal: true

# A check compares one expected value with what the model produced:
#   :correct    — matches (or both absent)
#   :wrong      — present but different
#   :missing    — expected a value, got none
#   :fabricated — no value exists in the source, but the model supplied one
#                 (or included a trap item that must not appear)
module Grading
  Check = Data.define(:field, :outcome, :expected, :actual)

  module_function

  def blank?(value) = value.nil? || (value.respond_to?(:empty?) && value.empty?)

  def norm(value) = value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").strip

  def digits(value) = value.to_s.gsub(/\D/, "")

  def matches?(expected, actual, kind)
    case kind
    when :text then norm(expected) == norm(actual)
    when :loose then !norm(actual).empty? && (norm(actual).include?(norm(expected)) || norm(expected).include?(norm(actual)))
    when :phone then digits(expected) == digits(actual)
    when :number then actual.is_a?(Numeric) && (expected - actual).abs <= 0.011
    else expected == actual
    end
  end

  def check(field, expected, actual, kind = :exact)
    outcome =
      if expected.nil? then blank?(actual) ? :correct : :fabricated
      elsif blank?(actual) && expected != false then :missing
      elsif matches?(expected, actual, kind) then :correct
      else :wrong
      end
    Check.new(field: field, outcome: outcome, expected: expected, actual: actual)
  end

  def exclusion(field, trap, values)
    hit = values.find { |v| norm(v).include?(norm(trap)) }
    Check.new(field: field, outcome: hit ? :fabricated : :correct, expected: "absent: #{trap}", actual: hit)
  end

  def constraint(field, ok, actual)
    Check.new(field: field, outcome: ok ? :correct : :wrong, expected: "constraint", actual: actual)
  end

  def invented(field, actual)
    Check.new(field: field, outcome: :fabricated, expected: nil, actual: actual)
  end

  # Matches each expected item to an unclaimed actual item, trying the keys
  # strictest first so near-duplicates (same day, same amount) pair with their
  # true counterpart before a looser key can claim them.
  def pair(expected, actual, *keys, &key)
    keys << key if key
    matched = {}
    remaining = actual.dup
    keys.each do |k|
      expected.each_with_index do |e, i|
        next if matched.key?(i)

        index = remaining.index { |a| k.call(e, a) }
        matched[i] = remaining.delete_at(index) if index
      end
    end
    [expected.each_with_index.map { |e, i| [e, matched[i]] }, remaining]
  end

  def summarize(checks)
    counts = checks.map(&:outcome).tally
    {
      total: checks.size,
      correct: counts.fetch(:correct, 0),
      wrong: counts.fetch(:wrong, 0),
      missing: counts.fetch(:missing, 0),
      fabricated: counts.fetch(:fabricated, 0),
      problems: checks.reject do |c|
        c.outcome == :correct
      end.map { |c| { field: c.field, outcome: c.outcome, expected: c.expected, actual: c.actual } },
    }
  end
end
