# frozen_string_literal: true

require "test_helper"

describe Riffer::Tracing::StreamRecorder do
  describe "#time_to_first_chunk" do
    def build_recorder(clock_values)
      remaining = clock_values.dup
      Riffer::Tracing::StreamRecorder.new([], clock: -> { remaining.shift })
    end

    it "measures from construction to the first event" do
      recorder = build_recorder([1.0, 1.5])
      recorder << Riffer::StreamEvents::TextDelta.new("Hi")

      expect(recorder.time_to_first_chunk).must_equal 0.5
    end

    it "counts a non-text event as the first chunk" do
      recorder = build_recorder([1.0, 1.25])
      recorder << Riffer::StreamEvents::ToolCallDelta.new(item_id: "call_1", name: "my_tool", arguments_delta: "{}")

      expect(recorder.time_to_first_chunk).must_equal 0.25
    end

    it "keeps the first measurement across subsequent events" do
      recorder = build_recorder([1.0, 1.5, 9.0])
      recorder << Riffer::StreamEvents::TextDelta.new("Hi")
      recorder << Riffer::StreamEvents::TextDone.new("Hi")

      expect(recorder.time_to_first_chunk).must_equal 0.5
    end

    it "is nil when no event arrives" do
      recorder = build_recorder([1.0])

      expect(recorder.time_to_first_chunk).must_be_nil
    end
  end
end
