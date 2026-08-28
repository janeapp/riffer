# frozen_string_literal: true

# rbs-inline stays disabled here: the generated signature would name Minitest,
# which a shipped signature must never reference. The hand-written stub lives in
# sig/_private/riffer/testing/minitest.rbs.

require "riffer"

# Wiring only — minitest is never a riffer dependency; a consumer requires this
# file from a test_helper that has already loaded the framework.
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
