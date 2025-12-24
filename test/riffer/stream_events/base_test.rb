# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::Base do
  describe "#initialize" do
    it "sets default role to assistant" do
      event = Riffer::StreamEvents::Base.new
      expect(event.role).must_equal "assistant"
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::Base.new(role: "user")
      expect(event.role).must_equal "user"
    end
  end

  describe "#to_h" do
    it "raises NotImplementedError" do
      event = Riffer::StreamEvents::Base.new
      expect { event.to_h }.must_raise(NotImplementedError)
    end
  end
end
