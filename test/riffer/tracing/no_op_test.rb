# frozen_string_literal: true

require "test_helper"

describe Riffer::Tracing::NoOp do
  describe "#in_span" do
    it "yields the frozen no-op span" do
      yielded = nil
      Riffer::Tracing::NoOp.in_span("test") { |span| yielded = span }

      expect(yielded).must_be_same_as Riffer::Tracing::NoOp::SPAN
    end

    it "returns the block's value" do
      result = Riffer::Tracing::NoOp.in_span("test") { :value }

      expect(result).must_equal :value
    end

    it "ignores span options" do
      result = Riffer::Tracing::NoOp.in_span("test", attributes: { "key" => "value" }, kind: :client) { :value }

      expect(result).must_equal :value
    end
  end

  describe "#current_context" do
    it "returns nil" do
      expect(Riffer::Tracing::NoOp.current_context).must_be_nil
    end
  end

  describe "#with_context" do
    it "returns the block's value" do
      result = Riffer::Tracing::NoOp.with_context(nil) { :value }

      expect(result).must_equal :value
    end
  end

  describe "SPAN" do
    it "is frozen" do
      expect(Riffer::Tracing::NoOp::SPAN).must_be :frozen?
    end

    it "is not recording" do
      expect(Riffer::Tracing::NoOp::SPAN.recording?).must_equal false
    end

    it "accepts every span operation without error" do
      span = Riffer::Tracing::NoOp::SPAN
      span.set_attribute("key", "value")
      span.add_event("event", attributes: { "key" => "value" })
      span.record_exception(Riffer::Error.new("boom"))
      span.error!("boom")
    end
  end
end
