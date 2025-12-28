# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Base do
  let(:provider) { Riffer::Providers::Base.new }

  describe ".identifier" do
    it "can be set and retrieved" do
      test_class = Class.new(Riffer::Providers::Base) do
        identifier "test_provider"
      end
      expect(test_class.identifier).must_equal "test_provider"
    end

    it "registers provider when identifier is set" do
      test_class = Class.new(Riffer::Providers::Base) do
        identifier "custom_provider"
      end
      expect(Riffer::Providers::Base.find("custom_provider")).must_equal test_class
    end
  end

  describe ".find" do
    it "returns registered provider class" do
      expect(Riffer::Providers::Base.find("openai")).must_equal Riffer::Providers::OpenAI
    end

    it "returns registered test provider class" do
      expect(Riffer::Providers::Base.find("test")).must_equal Riffer::Providers::Test
    end

    it "returns nil when provider not found" do
      expect(Riffer::Providers::Base.find("non_existent")).must_be_nil
    end
  end

  describe "#generate_text" do
    it "raises NotImplementedError when perform_generate_text not implemented" do
      error = expect { provider.generate_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #perform_generate_text"
    end

    it "raises ArgumentError when no prompt or messages provided" do
      error = expect { provider.generate_text }.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "prompt is required when messages is not provided"
    end

    it "raises ArgumentError when both prompt and messages provided" do
      error = expect do
        provider.generate_text(prompt: "Hello", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "cannot provide both prompt and messages"
    end

    it "raises ArgumentError when both system and messages provided" do
      error = expect do
        provider.generate_text(system: "You are helpful", messages: [{role: "user", content: "Hi"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "cannot provide both system and messages"
    end

    it "raises ArgumentError when messages has no user message" do
      error = expect do
        provider.generate_text(messages: [{role: "system", content: "You are helpful"}])
      end.must_raise(Riffer::ArgumentError)
      expect(error.message).must_equal "messages must include at least one user message"
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError when perform_stream_text not implemented" do
      error = expect { provider.stream_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #perform_stream_text"
    end
  end

  describe "#normalize_messages" do
    it "converts prompt to User message" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: nil, messages: nil)
      expect(result.all? { |msg| msg.is_a?(Riffer::Messages::Base) }).must_equal true
    end

    it "converts system and prompt to System and User messages" do
      result = provider.send(:normalize_messages, prompt: "Hello", system: "Be helpful", messages: nil)
      expect(result.all? { |msg| msg.is_a?(Riffer::Messages::Base) }).must_equal true
    end

    describe "with message objects" do
      let(:messages) do
        [
          Riffer::Messages::User.new("Hello"),
          Riffer::Messages::Assistant.new("Hi there")
        ]
      end

      it "preserves message objects when provided" do
        result = provider.send(:normalize_messages, prompt: nil, system: nil, messages: messages)
        expect(result).must_equal messages
      end
    end
  end
end
