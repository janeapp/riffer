# frozen_string_literal: true

require "test_helper"

describe Riffer::Instrumentation do
  after do
    Riffer.config.events.clear
  end

  describe "#instrument" do
    it "returns the block result" do
      result = Riffer::Instrumentation.instrument("op", attributes: {}, kind: :internal, event: ->(_result, _completion) {}) { |_span| 42 }
      expect(result).must_equal 42
    end

    it "does not let an event-builder failure break the operation" do
      Riffer.config.events.subscribe(->(event) {})
      result = Riffer::Instrumentation.instrument("op", attributes: {}, kind: :internal, event: ->(_result, _completion) { raise "build boom" }) { |_span| 42 }
      expect(result).must_equal 42
    end
  end
end
