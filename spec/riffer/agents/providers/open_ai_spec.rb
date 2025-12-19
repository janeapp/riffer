# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Providers::OpenAI do
  let(:api_key) { "test-api-key" }
  let(:provider) { described_class.new(api_key: api_key) }

  before do
    stub_request(:post, "https://api.openai.com/v1/responses")
      .to_return(
        status: 200,
        body: {
          id: "resp_123",
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: "Test response"
                }
              ]
            }
          ]
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )
  end

  describe "#generate_text" do
    it "returns a response hash with prompt" do
      result = provider.generate_text(prompt: "Hello")
      expect(result).to be_a(Hash)
    end

    it "returns a response hash with messages" do
      result = provider.generate_text(messages: [{role: "user", content: "Hello"}])
      expect(result).to be_a(Hash)
    end
  end

  describe "#stream_text" do
    before do
      stub_request(:post, "https://api.openai.com/v1/responses")
        .to_return(
          status: 200,
          body: "event: response.output_text.delta\ndata: {\"type\":\"response.output_text.delta\",\"text\":\"Test\"}\n\n",
          headers: {"Content-Type" => "text/event-stream"}
        )
    end

    it "returns an enumerator with prompt" do
      result = provider.stream_text(prompt: "Hello", model: "gpt-4.1")
      expect(result).to be_a(Enumerator)
    end

    it "returns an enumerator with messages" do
      result = provider.stream_text(messages: [{role: "user", content: "Hello"}], model: "gpt-4.1")
      expect(result).to be_a(Enumerator)
    end
  end
end
