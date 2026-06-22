# frozen_string_literal: true

require "test_helper"

describe Riffer::Metrics::NoOp do
  describe "#record_histogram" do
    it "ignores the measurement without error" do
      result = Riffer::Metrics::NoOp.record_histogram("riffer.test", 0.5, unit: "s", description: "d", attributes: {"k" => "v"})
      expect(result).must_be_nil
    end
  end
end
