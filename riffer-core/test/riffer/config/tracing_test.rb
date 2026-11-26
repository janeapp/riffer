# frozen_string_literal: true

require "test_helper"

describe Riffer::Config::Tracing do
  describe "#enabled" do
    it "initializes enabled to true" do
      tracing = Riffer::Config::Tracing.new

      expect(tracing.enabled).must_equal true
    end

    it "coerces a 'false' string for enabled" do
      tracing = Riffer::Config::Tracing.new
      tracing.enabled = "false"

      expect(tracing.enabled).must_equal false
    end

    it "coerces a 'true' string for enabled" do
      tracing = Riffer::Config::Tracing.new
      tracing.enabled = "true"

      expect(tracing.enabled).must_equal true
    end

    it "raises for an unrecognized enabled value" do
      tracing = Riffer::Config::Tracing.new

      expect { tracing.enabled = "yes" }.must_raise Riffer::ArgumentError
    end
  end

  describe "#capture_messages" do
    it "initializes capture_messages to false" do
      tracing = Riffer::Config::Tracing.new

      expect(tracing.capture_messages).must_equal false
    end

    it "coerces a 'true' string for capture_messages" do
      tracing = Riffer::Config::Tracing.new
      tracing.capture_messages = "true"

      expect(tracing.capture_messages).must_equal true
    end

    it "raises for an unrecognized capture_messages value" do
      tracing = Riffer::Config::Tracing.new

      expect { tracing.capture_messages = "yes" }.must_raise Riffer::ArgumentError
    end
  end

  describe "#backend" do
    it "initializes backend to nil" do
      tracing = Riffer::Config::Tracing.new

      expect(tracing.backend).must_be_nil
    end

    it "accepts a backend satisfying the tracing contract" do
      tracing = Riffer::Config::Tracing.new
      backend = Object.new
      def backend.in_span(*) = yield
      def backend.current_context = nil
      def backend.with_context(_) = yield
      tracing.backend = backend

      expect(tracing.backend).must_be_same_as backend
    end

    it "allows clearing the backend with nil" do
      tracing = Riffer::Config::Tracing.new
      tracing.backend = nil

      expect(tracing.backend).must_be_nil
    end

    it "raises for a backend missing every contract method" do
      tracing = Riffer::Config::Tracing.new

      expect { tracing.backend = Object.new }.must_raise Riffer::ArgumentError
    end

    it "raises for a backend that responds to in_span but not the context methods" do
      tracing = Riffer::Config::Tracing.new
      backend = Object.new
      def backend.in_span(*) = yield

      expect { tracing.backend = backend }.must_raise Riffer::ArgumentError
    end
  end
end
