# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::SkillActivation do
  describe "#initialize" do
    it "sets the name" do
      event = Riffer::StreamEvents::SkillActivation.new("code-review")

      expect(event.name).must_equal "code-review"
    end

    it "defaults role to system" do
      event = Riffer::StreamEvents::SkillActivation.new("code-review")

      expect(event.role).must_equal :system
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::SkillActivation.new("code-review", role: :assistant)

      expect(event.role).must_equal :assistant
    end
  end

  describe "#to_h" do
    it "returns hash with role and name" do
      event = Riffer::StreamEvents::SkillActivation.new("code-review")

      expect(event.to_h).must_equal({ role: :system, name: "code-review" })
    end
  end
end
