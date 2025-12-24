# frozen_string_literal: true

require "test_helper"

describe Riffer::Config do
  describe "#initialize" do
    it "initializes openai namespace" do
      config = Riffer::Config.new
      expect(config.openai).must_be_kind_of Struct
    end

    it "initializes with nil openai api_key" do
      config = Riffer::Config.new
      expect(config.openai.api_key).must_be_nil
    end
  end

  describe "openai namespace" do
    it "allows setting the api_key" do
      config = Riffer::Config.new
      config.openai.api_key = "test-key"
      expect(config.openai.api_key).must_equal "test-key"
    end
  end
end
