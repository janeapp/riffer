# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::FinishReason do
  describe "#initialize" do
    it "exposes the normalized reason" do
      finish_reason = Riffer::Providers::FinishReason.new(reason: :stop, raw: "end_turn")

      expect(finish_reason.reason).must_equal :stop
    end

    it "exposes the raw provider value" do
      finish_reason = Riffer::Providers::FinishReason.new(reason: :stop, raw: "end_turn")

      expect(finish_reason.raw).must_equal "end_turn"
    end

    it "defaults raw to nil" do
      finish_reason = Riffer::Providers::FinishReason.new(reason: :length)

      expect(finish_reason.raw).must_be_nil
    end

    it "raises on a reason outside the vocabulary" do
      error = expect { Riffer::Providers::FinishReason.new(reason: :bogus) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_include ":bogus"
    end
  end
end
