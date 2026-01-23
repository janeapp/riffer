# frozen_string_literal: true

require "test_helper"

describe Riffer do
  describe "TimeoutError" do
    it "is a subclass of Riffer::Error" do
      expect(Riffer::TimeoutError.superclass).must_equal Riffer::Error
    end
  end

  describe ".version" do
    it "has a version number" do
      expect(Riffer.version).wont_be_nil
    end
  end

  describe ".config" do
    it "returns a Config instance" do
      expect(Riffer.config).must_be_instance_of Riffer::Config
    end

    it "returns the same instance on multiple calls" do
      config1 = Riffer.config
      config2 = Riffer.config
      expect(config1.object_id).must_equal config2.object_id
    end
  end

  describe ".configure" do
    it "yields the config object" do
      yielded = nil
      Riffer.configure do |config|
        yielded = config
      end
      expect(yielded).must_be_instance_of Riffer::Config
    end

    it "allows setting configuration" do
      original_api_key = Riffer.config.openai.api_key
      Riffer.configure do |config|
        config.openai.api_key = "new-test-key"
      end
      expect(Riffer.config.openai.api_key).must_equal "new-test-key"
      # Restore original
      Riffer.config.openai.api_key = original_api_key
    end
  end
end
