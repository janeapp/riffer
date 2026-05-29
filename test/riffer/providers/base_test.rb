# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Base do
  let(:provider) { Riffer::Providers::Base.new }

  describe ".skills_adapter" do
    it "returns MarkdownAdapter by default" do
      expect(Riffer::Providers::Base.skills_adapter).must_equal Riffer::Skills::MarkdownAdapter
    end

    it "ignores the model argument" do
      expect(Riffer::Providers::Base.skills_adapter("anything/at-all")).must_equal Riffer::Skills::MarkdownAdapter
    end
  end

  describe "#generate_text" do
    it "raises NotImplementedError when hook methods not implemented" do
      error = expect { provider.generate_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #build_request_params"
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
    it "raises NotImplementedError when hook methods not implemented" do
      error = expect { provider.stream_text(prompt: "Hello") }.must_raise(NotImplementedError)
      expect(error.message).must_equal "Subclasses must implement #build_request_params"
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

  describe "#merge_consecutive_messages" do
    it "passes through alternating messages unchanged" do
      messages = [
        Riffer::Messages::User.new("Hello"),
        Riffer::Messages::Assistant.new("Hi"),
        Riffer::Messages::User.new("How are you?")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 3
    end

    it "passes through a single message unchanged" do
      messages = [Riffer::Messages::User.new("Hello")]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first.content).must_equal "Hello"
    end

    it "merges consecutive user messages" do
      messages = [
        Riffer::Messages::User.new("First"),
        Riffer::Messages::User.new("Second")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first).must_be_instance_of Riffer::Messages::User
      expect(result.first.content).must_equal "First\n\nSecond"
    end

    it "combines files when merging consecutive user messages" do
      file_a = Riffer::Messages::FilePart.new(data: "abc", media_type: "image/png")
      file_b = Riffer::Messages::FilePart.new(data: "def", media_type: "image/jpeg")
      messages = [
        Riffer::Messages::User.new("With image", files: [file_a]),
        Riffer::Messages::User.new("Another image", files: [file_b])
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first.files).must_equal [file_a, file_b]
    end

    it "merges consecutive system messages" do
      messages = [
        Riffer::Messages::System.new("Rule one"),
        Riffer::Messages::System.new("Rule two")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first).must_be_instance_of Riffer::Messages::System
      expect(result.first.content).must_equal "Rule one\n\nRule two"
    end

    it "merges consecutive assistant messages and combines tool calls" do
      tc = Riffer::Messages::Assistant::ToolCall.new(call_id: "1", name: "foo", arguments: "{}")
      messages = [
        Riffer::Messages::Assistant.new("Part one", tool_calls: [tc]),
        Riffer::Messages::Assistant.new("Part two")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 1
      expect(result.first).must_be_instance_of Riffer::Messages::Assistant
      expect(result.first.content).must_equal "Part one\n\nPart two"
      expect(result.first.tool_calls).must_equal [tc]
    end

    it "does not merge consecutive tool messages" do
      messages = [
        Riffer::Messages::Tool.new("Result A", tool_call_id: "1", name: "foo"),
        Riffer::Messages::Tool.new("Result B", tool_call_id: "2", name: "bar")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 2
    end

    it "only merges consecutive runs in a mixed sequence" do
      messages = [
        Riffer::Messages::System.new("System"),
        Riffer::Messages::User.new("Context"),
        Riffer::Messages::User.new("Question"),
        Riffer::Messages::Assistant.new("Answer"),
        Riffer::Messages::Tool.new("Result", tool_call_id: "1", name: "t"),
        Riffer::Messages::Tool.new("Result 2", tool_call_id: "2", name: "t2")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 5
      expect(result[0]).must_be_instance_of Riffer::Messages::System
      expect(result[1]).must_be_instance_of Riffer::Messages::User
      expect(result[1].content).must_equal "Context\n\nQuestion"
      expect(result[2]).must_be_instance_of Riffer::Messages::Assistant
      expect(result[3]).must_be_instance_of Riffer::Messages::Tool
      expect(result[4]).must_be_instance_of Riffer::Messages::Tool
    end

    it "merges context message with user message" do
      messages = [
        Riffer::Messages::System.new("You are helpful"),
        Riffer::Messages::User.new("Here is some context about the project"),
        Riffer::Messages::User.new("What does this code do?")
      ]

      result = provider.send(:merge_consecutive_messages, messages)

      expect(result.size).must_equal 2
      expect(result[0]).must_be_instance_of Riffer::Messages::System
      expect(result[1]).must_be_instance_of Riffer::Messages::User
      expect(result[1].content).must_equal "Here is some context about the project\n\nWhat does this code do?"
    end
  end
end
