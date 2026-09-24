# frozen_string_literal: true

# rbs-inline stays disabled: a shipped signature must never name Minitest. The
# stub lives in sig/_private/riffer/testing/minitest.rbs.

require "riffer"

# Minitest is never a riffer dependency; the consumer's test_helper loads it
# before requiring this file.
module Riffer::Testing::MinitestCleanup
  # Minitest reserves +after_teardown+ for library extensions; +teardown+
  # belongs to the test author.
  def after_teardown
    Riffer::Testing.reset!
    super
  end
end

Minitest::Test.include(Riffer::Testing)
Minitest::Test.include(Riffer::Testing::MinitestCleanup)
