# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Repository do
  describe ".find" do
    it "returns the OpenAI provider class for :openai symbol" do
      result = Riffer::Providers::Repository.find(:openai)
      expect(result).must_equal Riffer::Providers::OpenAI
    end

    it "returns the OpenAI provider class for 'openai' string" do
      result = Riffer::Providers::Repository.find("openai")
      expect(result).must_equal Riffer::Providers::OpenAI
    end

    it "returns the Test provider class for :test symbol" do
      expect(Riffer::Providers::Repository.find(:test)).must_equal Riffer::Providers::Test
    end

    it "returns the Test provider class for 'test' string" do
      expect(Riffer::Providers::Repository.find("test")).must_equal Riffer::Providers::Test
    end

    it "returns nil for unknown identifiers" do
      expect(Riffer::Providers::Repository.find(:missing)).must_be_nil
    end

    it "raises NoMethodError when identifier is nil" do
      expect { Riffer::Providers::Repository.find(nil) }.must_raise(NoMethodError)
    end
  end
end
