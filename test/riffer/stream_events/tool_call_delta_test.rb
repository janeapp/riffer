# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::ToolCallDelta do
  describe "#initialize" do
    it "sets the item_id" do
      event = Riffer::StreamEvents::ToolCallDelta.new(item_id: "call_123", arguments_delta: '{"city":')
      expect(event.item_id).must_equal "call_123"
    end

    it "sets the name" do
      event = Riffer::StreamEvents::ToolCallDelta.new(item_id: "call_123", name: "weather_lookup", arguments_delta: '{"city":')
      expect(event.name).must_equal "weather_lookup"
    end

    it "sets the arguments_delta" do
      event = Riffer::StreamEvents::ToolCallDelta.new(item_id: "call_123", arguments_delta: '{"city":')
      expect(event.arguments_delta).must_equal '{"city":'
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::ToolCallDelta.new(item_id: "call_123", arguments_delta: '{"city":')
      expect(event.role).must_equal "assistant"
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::ToolCallDelta.new(item_id: "call_123", arguments_delta: '{"city":', role: "custom")
      expect(event.role).must_equal "custom"
    end
  end

  describe "#to_h" do
    it "returns hash with role, item_id, name, and arguments_delta" do
      event = Riffer::StreamEvents::ToolCallDelta.new(
        item_id: "call_123",
        name: "weather_lookup",
        arguments_delta: '{"city":'
      )
      expected = {role: "assistant", item_id: "call_123", name: "weather_lookup", arguments_delta: '{"city":'}
      expect(event.to_h).must_equal expected
    end

    it "excludes nil name" do
      event = Riffer::StreamEvents::ToolCallDelta.new(item_id: "call_123", arguments_delta: '{"city":')
      expect(event.to_h.key?(:name)).must_equal false
    end
  end
end
