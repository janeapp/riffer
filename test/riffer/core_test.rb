# frozen_string_literal: true

require "test_helper"

describe Riffer::Core do
  describe "#initialize" do
    it "creates a logger instance" do
      core = Riffer::Core.new
      expect(core.logger).must_be_instance_of Logger
    end
  end

  describe "#configure" do
    it "yields self for configuration" do
      core = Riffer::Core.new
      yielded = nil
      core.configure do |c|
        yielded = c
      end
      expect(yielded).must_equal core
    end
  end
end
