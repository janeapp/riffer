# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::TokenUsageDone do
  let(:token_usage) { Riffer::TokenUsage.new(input_tokens: 100, output_tokens: 50) }

  describe "#initialize" do
    it "sets the token_usage" do
      event = Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage)
      expect(event.token_usage).must_equal token_usage
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage)
      expect(event.role).must_equal :assistant
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage, role: :user)
      expect(event.role).must_equal :user
    end
  end

  describe "#to_h" do
    it "returns hash with role" do
      event = Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage)
      expect(event.to_h[:role]).must_equal :assistant
    end

    it "returns hash with token_usage" do
      event = Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage)
      expect(event.to_h[:token_usage]).must_equal({input_tokens: 100, output_tokens: 50})
    end

    it "includes cache tokens in token_usage when present" do
      token_usage_with_cache = Riffer::TokenUsage.new(
        input_tokens: 100,
        output_tokens: 50,
        cache_creation_tokens: 25,
        cache_read_tokens: 10
      )
      event = Riffer::StreamEvents::TokenUsageDone.new(token_usage: token_usage_with_cache)
      expected_token_usage = {
        input_tokens: 100,
        output_tokens: 50,
        cache_creation_tokens: 25,
        cache_read_tokens: 10
      }
      expect(event.to_h[:token_usage]).must_equal expected_token_usage
    end
  end
end
