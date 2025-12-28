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
      expect(Riffer::Providers::Base.find_provider("custom_provider")).must_equal test_class
    end
  end

  describe ".find_provider" do
    it "returns registered provider class" do
      expect(Riffer::Providers::Base.find_provider("openai")).must_equal Riffer::Providers::OpenAI
    end

    it "returns registered test provider class" do
      expect(Riffer::Providers::Base.find_provider("test")).must_equal Riffer::Providers::Test
    end

    it "raises error when provider not found" do
      error = expect do
        Riffer::Providers::Base.find_provider("non_existent")
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_match(/Provider not found for identifier: non_existent/)
    end
  end

  describe "#generate_text" do
    it "raises NotImplementedError when perform_generate_text not implemented" do
      error = expect { provider.generate_text(prompt: "Hello", model: "test-model") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #perform_generate_text"
    end

    it "raises InvalidInputError when no prompt or messages provided" do
      error = expect { provider.generate_text(model: "test-model") }.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "prompt is required when messages is not provided"
    end

    it "raises InvalidInputError when both prompt and messages provided" do
      error = expect do
        provider.generate_text(prompt: "Hello", messages: [{role: "user", content: "Hi"}], model: "test-model")
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "cannot provide both prompt and messages"
    end

    it "raises InvalidInputError when both system and messages provided" do
      error = expect do
        provider.generate_text(system: "You are helpful", messages: [{role: "user", content: "Hi"}], model: "test-model")
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "cannot provide both system and messages"
    end

    it "raises InvalidInputError when messages has no user message" do
      error = expect do
        provider.generate_text(messages: [{role: "system", content: "You are helpful"}], model: "test-model")
      end.must_raise(Riffer::Providers::InvalidInputError)
      expect(error.message).must_equal "messages must include at least one user message"
    end

    describe "model validation" do
      it "raises InvalidInputError when model is nil" do
        error = expect {
          provider.generate_text(prompt: "Hello", model: nil)
        }.must_raise(Riffer::Providers::InvalidInputError)
        expect(error.message).must_equal "model is required"
      end

      it "raises InvalidInputError when model is empty string" do
        error = expect {
          provider.generate_text(prompt: "Hello", model: "")
        }.must_raise(Riffer::Providers::InvalidInputError)
        expect(error.message).must_equal "model cannot be empty"
      end

      it "raises InvalidInputError when model is whitespace only" do
        error = expect {
          provider.generate_text(prompt: "Hello", model: "   ")
        }.must_raise(Riffer::Providers::InvalidInputError)
        expect(error.message).must_equal "model cannot be empty"
      end
    end
  end

  describe "#stream_text" do
    it "raises NotImplementedError when perform_stream_text not implemented" do
      error = expect { provider.stream_text(prompt: "Hello", model: "test-model") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #perform_stream_text"
    end

    describe "model validation" do
      it "raises InvalidInputError when model is nil" do
        error = expect {
          provider.stream_text(prompt: "Hello", model: nil)
        }.must_raise(Riffer::Providers::InvalidInputError)
        expect(error.message).must_equal "model is required"
      end

      it "raises InvalidInputError when model is empty string" do
        error = expect {
          provider.stream_text(prompt: "Hello", model: "")
        }.must_raise(Riffer::Providers::InvalidInputError)
        expect(error.message).must_equal "model cannot be empty"
      end
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
