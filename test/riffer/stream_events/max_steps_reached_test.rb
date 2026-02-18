# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::MaxStepsReached do
  describe "#initialize" do
    it "defaults role to assistant" do
      event = Riffer::StreamEvents::MaxStepsReached.new
      expect(event.role).must_equal :assistant
    end

    it "allows custom role" do
      event = Riffer::StreamEvents::MaxStepsReached.new(role: :system)
      expect(event.role).must_equal :system
    end
  end

  describe "inheritance" do
    it "inherits from Base" do
      event = Riffer::StreamEvents::MaxStepsReached.new
      expect(event).must_be_kind_of Riffer::StreamEvents::Base
    end
  end

  describe "#to_h" do
    it "returns hash with role" do
      event = Riffer::StreamEvents::MaxStepsReached.new
      expect(event.to_h).must_equal({role: :assistant})
    end

    it "returns hash with custom role" do
      event = Riffer::StreamEvents::MaxStepsReached.new(role: :system)
      expect(event.to_h).must_equal({role: :system})
    end
  end
end
