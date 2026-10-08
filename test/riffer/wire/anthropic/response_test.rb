# frozen_string_literal: true

require "test_helper"

describe Riffer::Wire::Anthropic::Response do
  let(:tool) do
    stub_tool("Lookup") { description "Look things up" }.tap { |t| t.identifier("crm/lookup") }
  end

  def response(content: [], **body)
    Riffer::Wire::Anthropic::Response.new({ content: content, **body }, tools: [tool])
  end

  describe "#content" do
    it "joins every text block, skipping other blocks" do
      content = [
        { type: "thinking", thinking: "Hmm", signature: "sig" },
        { type: "text", text: "Searching. " },
        { type: "server_tool_use", id: "srvtoolu_1", name: "web_search", input: { query: "ruby" } },
        { type: "web_search_tool_result", tool_use_id: "srvtoolu_1", content: [] },
        { type: "text", text: "Ruby 4.0 is out." },
      ]

      expect(response(content: content).content).must_equal "Searching. Ruby 4.0 is out."
    end

    it "returns an empty string without content" do
      expect(Riffer::Wire::Anthropic::Response.new({}).content).must_equal ""
    end
  end

  describe "#tool_calls" do
    it "maps tool_use blocks, decoding the wire tool name" do
      content = [{ type: "tool_use", id: "toolu_1", name: "crm__lookup", input: { "id" => 7 } }]

      expect(response(content: content).tool_calls.map(&:to_h)).must_equal [
        { call_id: "toolu_1", name: "crm/lookup", arguments: '{"id":7}' },
      ]
    end

    it "leaves an unknown tool name as sent" do
      content = [{ type: "tool_use", id: "toolu_1", name: "other__tool", input: {} }]

      expect(response(content: content).tool_calls.first.name).must_equal "other__tool"
    end
  end

  describe "#reasoning" do
    it "maps thinking and redacted_thinking blocks in order" do
      content = [
        { type: "thinking", thinking: "Think", signature: "sig" },
        { type: "redacted_thinking", data: "opaque" },
        { type: "text", text: "42" },
      ]

      expect(response(content: content).reasoning.map(&:to_h)).must_equal [
        { type: :text, text: "Think", signature: "sig", format: "anthropic-messages-v1" },
        { type: :encrypted, data: "opaque", format: "anthropic-messages-v1" },
      ]
    end
  end

  describe "#token_usage" do
    it "folds the cache buckets into input_tokens" do
      usage = response(
        usage: { input_tokens: 10, output_tokens: 5, cache_creation_input_tokens: 20, cache_read_input_tokens: 30 },
      ).token_usage

      expect(usage.to_h).must_equal({ input_tokens: 60, output_tokens: 5, cache_write_tokens: 20,
                                      cache_read_tokens: 30, })
    end

    it "treats unreported cache buckets as zero" do
      usage = response(usage: { input_tokens: 10, output_tokens: 5 }).token_usage

      expect([usage.input_tokens, usage.cache_read_tokens]).must_equal [10, nil]
    end

    it "returns nil without usage" do
      expect(response.token_usage).must_be_nil
    end
  end

  describe "#finish_reason" do
    it "normalizes the stop reason and keeps the raw value" do
      finish_reason = response(stop_reason: "tool_use").finish_reason

      expect([finish_reason.reason, finish_reason.raw]).must_equal [:tool_calls, "tool_use"]
    end

    it "normalizes unknown values to other" do
      expect(response(stop_reason: "mystery").finish_reason.reason).must_equal :other
    end

    it "returns nil without a stop reason" do
      expect(response.finish_reason).must_be_nil
    end
  end
end
