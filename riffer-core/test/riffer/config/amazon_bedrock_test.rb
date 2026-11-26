# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::AmazonBedrock do
  describe "#api_token" do
    it "initializes to nil" do
      expect(Riffer::Config::AmazonBedrock.new.api_token).must_be_nil
    end

    it "accepts a string" do
      section = Riffer::Config::AmazonBedrock.new
      section.api_token = "value"

      expect(section.api_token).must_equal "value"
    end

    it "accepts an empty string" do
      section = Riffer::Config::AmazonBedrock.new
      section.api_token = ""

      expect(section.api_token).must_equal ""
    end

    it "allows clearing with nil" do
      section = Riffer::Config::AmazonBedrock.new
      section.api_token = "value"
      section.api_token = nil

      expect(section.api_token).must_be_nil
    end

    it "raises for a non-string, naming the attribute" do
      section = Riffer::Config::AmazonBedrock.new
      error = expect { section.api_token = :value }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^api_token /)
    end
  end

  describe "#region" do
    it "initializes to nil" do
      expect(Riffer::Config::AmazonBedrock.new.region).must_be_nil
    end

    it "accepts a string" do
      section = Riffer::Config::AmazonBedrock.new
      section.region = "value"

      expect(section.region).must_equal "value"
    end

    it "accepts an empty string" do
      section = Riffer::Config::AmazonBedrock.new
      section.region = ""

      expect(section.region).must_equal ""
    end

    it "allows clearing with nil" do
      section = Riffer::Config::AmazonBedrock.new
      section.region = "value"
      section.region = nil

      expect(section.region).must_be_nil
    end

    it "raises for a non-string, naming the attribute" do
      section = Riffer::Config::AmazonBedrock.new
      error = expect { section.region = :value }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^region /)
    end
  end

  describe "#client" do
    it "initializes to nil" do
      expect(Riffer::Config::AmazonBedrock.new.client).must_be_nil
    end

    it "accepts any object" do
      section = Riffer::Config::AmazonBedrock.new
      client = Object.new
      section.client = client

      expect(section.client).must_be_same_as client
    end
  end
end
