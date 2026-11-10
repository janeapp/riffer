# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::Mcp do
  describe "deprecation" do
    after { reset_riffer_config! }

    it "raises the config_mcp deprecation from credentials= in :raise mode" do
      mcp = Riffer::Config::Mcp.new
      error = expect { mcp.credentials = nil }.must_raise Riffer::DeprecationError

      expect(error.message).must_match(/config.mcp is deprecated/)
    end

    it "raises the config_mcp deprecation from discovery_runner= in :raise mode" do
      mcp = Riffer::Config::Mcp.new
      error = expect { mcp.discovery_runner = Riffer::Runner::Sequential.new }.must_raise Riffer::DeprecationError

      expect(error.message).must_match(/config.mcp is deprecated/)
    end

    it "reports the caller of each setter as the location" do
      events = []
      Riffer.config.deprecations = ->(event) { events << event }
      mcp = Riffer::Config::Mcp.new
      line = __LINE__ + 1
      mcp.credentials = nil
      mcp.discovery_runner = Riffer::Runner::Sequential.new

      expect(events.map { |event| [event.id, event.location] }).must_equal [
        [:config_mcp, "#{__FILE__}:#{line}"],
        [:config_mcp, "#{__FILE__}:#{line + 1}"],
      ]
    end
  end

  describe "#credentials" do
    it "initializes to nil" do
      expect(Riffer::Config::Mcp.new.credentials).must_be_nil
    end

    it "accepts a callable" do
      mcp = Riffer::Config::Mcp.new
      credentials = ->(manifest:, matched_tags:, context:) { {} }
      allow_deprecations { mcp.credentials = credentials }

      expect(mcp.credentials).must_be_same_as credentials
    end

    it "allows clearing with nil" do
      mcp = Riffer::Config::Mcp.new
      allow_deprecations do
        mcp.credentials = ->(**) { {} }
        mcp.credentials = nil
      end

      expect(mcp.credentials).must_be_nil
    end

    it "raises for an object that doesn't respond to #call" do
      mcp = Riffer::Config::Mcp.new
      error = expect { allow_deprecations { mcp.credentials = { "Authorization" => "Bearer x" } } }.must_raise Riffer::ArgumentError

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
      allow_deprecations { mcp.discovery_runner = runner }

      expect(mcp.discovery_runner).must_be_same_as runner
    end

    it "raises for a runner that isn't a Riffer::Runner instance" do
      mcp = Riffer::Config::Mcp.new
      error = expect { allow_deprecations { mcp.discovery_runner = Object.new } }.must_raise Riffer::ArgumentError

      expect(error.message).must_match(/^discovery_runner /)
    end
  end
end
