# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::Interrupt do
  describe "#initialize" do
    it "defaults role to system" do
      event = Riffer::StreamEvents::Interrupt.new
      expect(event.role).must_equal :system
    end
  end

  describe "#to_h" do
    it "returns hash with role" do
      event = Riffer::StreamEvents::Interrupt.new
      expect(event.to_h).must_equal({role: :system, interrupt: true})
    end
  end
end
