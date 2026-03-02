# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::Interrupt do
  describe "#initialize" do
    it "defaults role to system" do
      event = Riffer::StreamEvents::Interrupt.new
      expect(event.role).must_equal :system
    end

    it "accepts a symbol reason" do
      event = Riffer::StreamEvents::Interrupt.new(reason: :max_steps)
      expect(event.reason).must_equal :max_steps
    end
  end

  describe "#step" do
    it "defaults to 0" do
      event = Riffer::StreamEvents::Interrupt.new
      expect(event.step).must_equal 0
    end

    it "stores the step count" do
      event = Riffer::StreamEvents::Interrupt.new(step: 3)
      expect(event.step).must_equal 3
    end
  end

  describe "#to_h" do
    it "returns hash with role and step" do
      event = Riffer::StreamEvents::Interrupt.new
      expect(event.to_h).must_equal({role: :system, interrupt: true, step: 0})
    end

    it "includes symbol reason in hash" do
      event = Riffer::StreamEvents::Interrupt.new(reason: :max_steps, step: 2)
      expect(event.to_h).must_equal({role: :system, interrupt: true, step: 2, reason: :max_steps})
    end
  end
end
