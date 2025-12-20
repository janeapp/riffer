# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Providers::OpenAI, :vcr do
  let(:api_key) { ENV.fetch("OPENAI_API_KEY", "test_api_key") }

  describe "#initialize" do
    it "raises ArgumentError when api_key is nil" do
      expect { described_class.new(api_key: nil) }.to raise_error(ArgumentError, /openai api key is required/i)
    end

    it "raises ArgumentError when api_key is empty" do
      expect { described_class.new(api_key: "") }.to raise_error(ArgumentError, /openai api key is required/i)
    end

    it "creates OpenAI client with api_key" do
      provider = described_class.new(api_key: api_key)
      expect(provider).to be_a(described_class)
    end

    it "accepts additional options" do
      provider = described_class.new(api_key: api_key, organization: "org-123")
      expect(provider).to be_a(described_class)
    end
  end

  describe "#generate_text" do
    let(:provider) { described_class.new(api_key: api_key) }

    context "when prompt is provided" do
      it "returns an Assistant message" do
        result = provider.generate_text(prompt: "Say hello", model: "gpt-5-nano")
        expect(result).to be_a(Riffer::Messages::Assistant)
      end
    end

    context "when system and prompt are provided" do
      let(:params) { {system: "Be concise", prompt: "Say hello", model: "gpt-5-nano"} }

      it "returns an Assistant message" do
        result = provider.generate_text(**params)

        expect(result).to be_a(Riffer::Messages::Assistant)
      end
    end

    context "with a hash messages array" do
      let(:messages) do
        [
          {role: "system", content: "Be concise"},
          {role: "user", content: "Say hello"}
        ]
      end

      it "returns an Assistant message" do
        result = provider.generate_text(messages: messages, model: "gpt-5-nano")
        expect(result).to be_a(Riffer::Messages::Assistant)
      end
    end

    context "with a User message" do
      let(:messages) do
        [Riffer::Messages::User.new("Say hello")]
      end

      it "returns an Assistant" do
        result = provider.generate_text(messages: messages, model: "gpt-5-nano")
        expect(result).to be_a(Riffer::Messages::Assistant)
      end
    end

    context "with a System message" do
      let(:messages) do
        [
          Riffer::Messages::System.new("Be concise"),
          Riffer::Messages::User.new("Say hello")
        ]
      end

      it "returns an Assistant message" do
        result = provider.generate_text(messages: messages, model: "gpt-5-nano")
        expect(result).to be_a(Riffer::Messages::Assistant)
      end
    end

    context "with an Assistant message" do
      let(:messages) do
        [
          Riffer::Messages::User.new("Say hello"),
          Riffer::Messages::Assistant.new("Hello!"),
          Riffer::Messages::User.new("How are you?")
        ]
      end

      it "returns an Assistant message" do
        result = provider.generate_text(messages: messages, model: "gpt-5-nano")
        expect(result).to be_a(Riffer::Messages::Assistant)
      end
    end
  end

  describe "#stream_text" do
    let(:provider) { described_class.new(api_key: api_key) }

    context "when prompt is provided" do
      it "returns an Enumerator" do
        result = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano")
        expect(result).to be_a(Enumerator)
      end

      it "yields stream events" do
        events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
        expect(events).not_to be_empty
      end

      it "yields TextDelta events" do
        events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
        deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
        expect(deltas).not_to be_empty
      end

      it "yields TextDone event" do
        events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
        done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
        expect(done).not_to be_nil
      end
    end

    context "when messages are provided" do
      it "returns an Enumerator" do
        result = provider.stream_text(
          messages: [{role: "user", content: "Say hello"}],
          model: "gpt-5-nano"
        )
        expect(result).to be_a(Enumerator)
      end

      it "yields stream events" do
        events = provider.stream_text(
          messages: [{role: "user", content: "Say hello"}],
          model: "gpt-5-nano"
        ).to_a
        expect(events).not_to be_empty
      end
    end
  end
end
