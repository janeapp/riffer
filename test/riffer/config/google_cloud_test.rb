# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::GoogleCloud do
  describe "#project_id" do
    it "initializes to nil" do
      expect(Riffer::Config::GoogleCloud.new.project_id).must_be_nil
    end

    it "accepts a string" do
      section = Riffer::Config::GoogleCloud.new
      section.project_id = "value"

      expect(section.project_id).must_equal "value"
    end

    it "allows clearing with nil" do
      section = Riffer::Config::GoogleCloud.new
      section.project_id = "value"
      section.project_id = nil

      expect(section.project_id).must_be_nil
    end

    it "raises for a non-string, naming the attribute" do
      section = Riffer::Config::GoogleCloud.new
      error = expect { section.project_id = :value }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^project_id /)
    end
  end

  describe "#location" do
    it "initializes to global" do
      expect(Riffer::Config::GoogleCloud.new.location).must_equal "global"
    end

    it "accepts a string" do
      section = Riffer::Config::GoogleCloud.new
      section.location = "us-central1"

      expect(section.location).must_equal "us-central1"
    end

    it "restores global when cleared with nil" do
      section = Riffer::Config::GoogleCloud.new
      section.location = "us-central1"
      section.location = nil

      expect(section.location).must_equal "global"
    end

    it "raises for a non-string, naming the attribute" do
      section = Riffer::Config::GoogleCloud.new
      error = expect { section.location = :value }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^location /)
    end
  end

  describe "#credentials" do
    it "initializes to nil" do
      expect(Riffer::Config::GoogleCloud.new.credentials).must_be_nil
    end

    it "accepts any object" do
      section = Riffer::Config::GoogleCloud.new
      credentials = Object.new
      section.credentials = credentials

      expect(section.credentials).must_be_same_as credentials
    end
  end

  describe "#client" do
    it "initializes to nil" do
      expect(Riffer::Config::GoogleCloud.new.client).must_be_nil
    end

    it "accepts any object" do
      section = Riffer::Config::GoogleCloud.new
      client = Object.new
      section.client = client

      expect(section.client).must_be_same_as client
    end
  end
end
