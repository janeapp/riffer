# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::FinishReasonDone do
  describe "#initialize" do
    it "sets the finish_reason" do
      event = Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :stop)

      expect(event.finish_reason).must_equal :stop
    end

    it "sets the raw_finish_reason" do
      event = Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :stop, raw_finish_reason: "end_turn")

      expect(event.raw_finish_reason).must_equal "end_turn"
    end

    it "defaults raw_finish_reason to nil" do
      event = Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :stop)

      expect(event.raw_finish_reason).must_be_nil
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :stop)

      expect(event.role).must_equal :assistant
    end

    it "raises on a finish_reason outside the vocabulary" do
      error = expect { Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :bogus) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_include ":bogus"
    end
  end

  describe "#to_h" do
    it "returns hash with role and finish_reason" do
      event = Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :length)

      expect(event.to_h).must_equal({ role: :assistant, finish_reason: :length })
    end

    it "includes raw_finish_reason when present" do
      event = Riffer::StreamEvents::FinishReasonDone.new(finish_reason: :length, raw_finish_reason: "MAX_TOKENS")

      expect(event.to_h).must_equal({ role: :assistant, finish_reason: :length, raw_finish_reason: "MAX_TOKENS" })
    end
  end
end
