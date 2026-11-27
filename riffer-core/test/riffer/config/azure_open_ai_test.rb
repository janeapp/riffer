# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::AzureOpenAI do
  describe "#api_key" do
    it "initializes to nil" do
      expect(Riffer::Config::AzureOpenAI.new.api_key).must_be_nil
    end

    it "accepts a string" do
      section = Riffer::Config::AzureOpenAI.new
      section.api_key = "value"

      expect(section.api_key).must_equal "value"
    end

    it "accepts an empty string" do
      section = Riffer::Config::AzureOpenAI.new
      section.api_key = ""

      expect(section.api_key).must_equal ""
    end

    it "allows clearing with nil" do
      section = Riffer::Config::AzureOpenAI.new
      section.api_key = "value"
      section.api_key = nil

      expect(section.api_key).must_be_nil
    end

    it "raises for a non-string, naming the attribute" do
      section = Riffer::Config::AzureOpenAI.new
      error = expect { section.api_key = :value }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^api_key /)
    end
  end

  describe "#endpoint" do
    it "initializes to nil" do
      expect(Riffer::Config::AzureOpenAI.new.endpoint).must_be_nil
    end

    it "accepts a string" do
      section = Riffer::Config::AzureOpenAI.new
      section.endpoint = "value"

      expect(section.endpoint).must_equal "value"
    end

    it "accepts an empty string" do
      section = Riffer::Config::AzureOpenAI.new
      section.endpoint = ""

      expect(section.endpoint).must_equal ""
    end

    it "allows clearing with nil" do
      section = Riffer::Config::AzureOpenAI.new
      section.endpoint = "value"
      section.endpoint = nil

      expect(section.endpoint).must_be_nil
    end

    it "raises for a non-string, naming the attribute" do
      section = Riffer::Config::AzureOpenAI.new
      error = expect { section.endpoint = :value }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^endpoint /)
    end
  end

  describe "#client" do
    it "initializes to nil" do
      expect(Riffer::Config::AzureOpenAI.new.client).must_be_nil
    end

    it "accepts any object" do
      section = Riffer::Config::AzureOpenAI.new
      client = Object.new
      section.client = client

      expect(section.client).must_be_same_as client
    end
  end
end
