# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::OpenRouter do
  describe "#api_key" do
    it "initializes to nil" do
      expect(Riffer::Config::OpenRouter.new.api_key).must_be_nil
    end

    it "accepts a string" do
      section = Riffer::Config::OpenRouter.new
      section.api_key = "value"

      expect(section.api_key).must_equal "value"
    end

    it "accepts an empty string" do
      section = Riffer::Config::OpenRouter.new
      section.api_key = ""

      expect(section.api_key).must_equal ""
    end

    it "allows clearing with nil" do
      section = Riffer::Config::OpenRouter.new
      section.api_key = "value"
      section.api_key = nil

      expect(section.api_key).must_be_nil
    end

    it "raises for a non-string, naming the attribute" do
      section = Riffer::Config::OpenRouter.new
      error = expect { section.api_key = :value }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^api_key /)
    end
  end

  describe "#client" do
    it "initializes to nil" do
      expect(Riffer::Config::OpenRouter.new.client).must_be_nil
    end

    it "accepts any object" do
      section = Riffer::Config::OpenRouter.new
      client = Object.new
      section.client = client

      expect(section.client).must_be_same_as client
    end
  end
end
