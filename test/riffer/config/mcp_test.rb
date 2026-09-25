# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::Mcp do
  describe "#credentials" do
    it "initializes to nil" do
      expect(Riffer::Config::Mcp.new.credentials).must_be_nil
    end

    it "accepts a callable" do
      mcp = Riffer::Config::Mcp.new
      credentials = ->(manifest:, matched_tags:, context:) { {} }
      mcp.credentials = credentials

      expect(mcp.credentials).must_be_same_as credentials
    end

    it "allows clearing with nil" do
      mcp = Riffer::Config::Mcp.new
      mcp.credentials = ->(**) { {} }
      mcp.credentials = nil

      expect(mcp.credentials).must_be_nil
    end

    it "raises for an object that doesn't respond to #call" do
      mcp = Riffer::Config::Mcp.new
      error = expect { mcp.credentials = { "Authorization" => "Bearer x" } }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^credentials /)
    end
  end

  describe "#discovery_runner" do
    it "initializes to a Sequential instance" do
      expect(Riffer::Config::Mcp.new.discovery_runner).must_be_instance_of Riffer::Runner::Sequential
    end

    it "accepts a Riffer::Runner instance" do
      mcp = Riffer::Config::Mcp.new
      runner = Riffer::Runner::Threaded.new
      mcp.discovery_runner = runner

      expect(mcp.discovery_runner).must_be_same_as runner
    end

    it "raises for a runner that isn't a Riffer::Runner instance" do
      mcp = Riffer::Config::Mcp.new
      error = expect { mcp.discovery_runner = Object.new }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^discovery_runner /)
    end
  end
end
