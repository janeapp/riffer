# frozen_string_literal: true
# rbs_inline: enabled

require "riffer"

# Wiring only — RSpec is never a riffer dependency; a consumer requires this
# file from a spec_helper that has already loaded the framework.
RSpec.configure do |config|
  config.include Riffer::Testing
  config.after { Riffer::Testing.reset! }
end
