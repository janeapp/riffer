# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::UsageDone do
  let(:usage) { Riffer::Usage.new(input_tokens: 100, output_tokens: 50) }

  describe "#initialize" do
    it "sets the usage" do
      event = Riffer::StreamEvents::UsageDone.new(usage: usage)
      expect(event.usage).must_equal usage
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::UsageDone.new(usage: usage)
      expect(event.role).must_equal :assistant
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::UsageDone.new(usage: usage, role: :user)
      expect(event.role).must_equal :user
    end
  end

  describe "#to_h" do
    it "returns hash with role" do
      event = Riffer::StreamEvents::UsageDone.new(usage: usage)
      expect(event.to_h[:role]).must_equal :assistant
    end

    it "returns hash with usage" do
      event = Riffer::StreamEvents::UsageDone.new(usage: usage)
      expect(event.to_h[:usage]).must_equal({input_tokens: 100, output_tokens: 50})
    end

    it "includes cache tokens in usage when present" do
      usage_with_cache = Riffer::Usage.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_creation_tokens: 25,
        cache_read_tokens: 10
      )
      event = Riffer::StreamEvents::UsageDone.new(usage: usage_with_cache)
      expected_usage = {
        input_tokens: 100,
        output_tokens: 50,
        cache_creation_tokens: 25,
        cache_read_tokens: 10
      }
      expect(event.to_h[:usage]).must_equal expected_usage
    end
  end
end
