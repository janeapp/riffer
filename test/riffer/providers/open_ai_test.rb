# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::OpenAI do
  let(:api_key) { ENV.fetch("OPENAI_API_KEY", "test_api_key") }

  describe "#initialize" do
    it "raises ArgumentError when api_key is nil" do
      error = expect { Riffer::Providers::OpenAI.new(api_key: nil) }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/openai api key is required/i)
    end

    it "raises ArgumentError when api_key is empty" do
      error = expect { Riffer::Providers::OpenAI.new(api_key: "") }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_match(/openai api key is required/i)
    end

    it "creates OpenAI client with api_key" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key)
      expect(provider).must_be_instance_of Riffer::Providers::OpenAI
    end

    it "accepts additional options" do
      provider = Riffer::Providers::OpenAI.new(api_key: api_key, organization: "org-123")
      expect(provider).must_be_instance_of Riffer::Providers::OpenAI
    end
  end

  describe "#generate_text" do
    describe "when prompt is provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/when_prompt_is_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.generate_text(prompt: "Say hello", model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "when system and prompt are provided" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/when_system_and_prompt_are_provided/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          params = {system: "Be concise", prompt: "Say hello", model: "gpt-5-nano"}
          result = provider.generate_text(**params)
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a hash messages array" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_a_hash_messages_array/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            {role: "system", content: "Be concise"},
            {role: "user", content: "Say hello"}
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a User message" do
      it "returns an Assistant" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_a_User_message/returns_an_Assistant") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [Riffer::Messages::User.new("Say hello")]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with a System message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_a_System_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            Riffer::Messages::System.new("Be concise"),
            Riffer::Messages::User.new("Say hello")
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end

    describe "with an Assistant message" do
      it "returns an Assistant message" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_generate_text/with_an_Assistant_message/returns_an_Assistant_message") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          messages = [
            Riffer::Messages::User.new("Say hello"),
            Riffer::Messages::Assistant.new("Hello!"),
            Riffer::Messages::User.new("How are you?")
          ]
          result = provider.generate_text(messages: messages, model: "gpt-5-nano")
          expect(result).must_be_instance_of Riffer::Messages::Assistant
        end
      end
    end
  end

  describe "#stream_text" do
    describe "when prompt is provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano")
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          expect(events).wont_be_empty
        end
      end

      it "yields TextDelta events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_TextDelta_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          deltas = events.select { |e| e.is_a?(Riffer::StreamEvents::TextDelta) }
          expect(deltas).wont_be_empty
        end
      end

      it "yields TextDone event" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_prompt_is_provided/yields_TextDone_event") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(prompt: "Say hello", model: "gpt-5-nano").to_a
          done = events.find { |e| e.is_a?(Riffer::StreamEvents::TextDone) }
          expect(done).wont_be_nil
        end
      end
    end

    describe "when messages are provided" do
      it "returns an Enumerator" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          result = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "gpt-5-nano"
          )
          expect(result).must_be_instance_of Enumerator
        end
      end

      it "yields stream events" do
        VCR.use_cassette("Riffer_Providers_OpenAI/_stream_text/when_messages_are_provided/yields_stream_events") do
          provider = Riffer::Providers::OpenAI.new(api_key: api_key)
          events = provider.stream_text(
            messages: [{role: "user", content: "Say hello"}],
            model: "gpt-5-nano"
          ).to_a
          expect(events).wont_be_empty
        end
      end
    end
  end
end
