# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::ToolCallDone do
  describe "#initialize" do
    it "sets the item_id" do
      event = Riffer::StreamEvents::ToolCallDone.new(
        item_id: "item_123",
        call_id: "call_123",
        name: "weather_lookup",
        arguments: '{"city":"Toronto"}'
      )
      expect(event.item_id).must_equal "item_123"
    end

    it "sets the call_id" do
      event = Riffer::StreamEvents::ToolCallDone.new(
        item_id: "item_123",
        call_id: "call_123",
        name: "weather_lookup",
        arguments: '{"city":"Toronto"}'
      )
      expect(event.call_id).must_equal "call_123"
    end

    it "sets the name" do
      event = Riffer::StreamEvents::ToolCallDone.new(
        item_id: "item_123",
        call_id: "call_123",
        name: "weather_lookup",
        arguments: '{"city":"Toronto"}'
      )
      expect(event.name).must_equal "weather_lookup"
    end

    it "sets the arguments" do
      event = Riffer::StreamEvents::ToolCallDone.new(
        item_id: "item_123",
        call_id: "call_123",
        name: "weather_lookup",
        arguments: '{"city":"Toronto"}'
      )
      expect(event.arguments).must_equal '{"city":"Toronto"}'
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::ToolCallDone.new(
        item_id: "item_123",
        call_id: "call_123",
        name: "weather_lookup",
        arguments: '{"city":"Toronto"}'
      )
      expect(event.role).must_equal :assistant
    end
  end

  describe "#to_h" do
    it "returns hash with all fields" do
      event = Riffer::StreamEvents::ToolCallDone.new(
        item_id: "item_123",
        call_id: "call_123",
        name: "weather_lookup",
        arguments: '{"city":"Toronto"}'
      )
      expected = {
        role: :assistant,
        item_id: "item_123",
        call_id: "call_123",
        name: "weather_lookup",
        arguments: '{"city":"Toronto"}'
      }
      expect(event.to_h).must_equal expected
    end
  end
end
