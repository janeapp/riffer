# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Base do
  let(:agent_class) do
    Class.new(described_class) do
      model "test/riffer-1"
      instructions "You are a helpful assistant."
    end
  end

  describe ".model" do
    it "sets the model" do
      expect(agent_class.model).to eq("test/riffer-1")
    end
  end

  describe ".instructions" do
    it "sets the instructions" do
      expect(agent_class.instructions).to eq("You are a helpful assistant.")
    end

    it "raises error when instructions is not a string" do
      expect {
        agent_class.instructions(123)
      }.to raise_error(ArgumentError, /instructions must be a String/)
    end
  end

  describe "#initialize" do
    it "initializes with empty messages" do
      agent = agent_class.new
      expect(agent.messages).to eq([])
    end
  end

  describe "#generate" do
    context "with test provider" do
      it "returns a text response" do
        agent = agent_class.new
        result = agent.generate("What is the weather?")
        expect(result).to be_a(String)
      end

      it "adds system message to messages when instructions are provided" do
        agent = agent_class.new
        agent.generate("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::System) }
        expect(system_message).not_to be_nil
      end

      it "adds user message to messages" do
        agent = agent_class.new
        agent.generate("Hello")
        user_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::User) }
        expect(user_message).not_to be_nil
      end

      it "adds assistant message to messages" do
        agent = agent_class.new
        agent.generate("Hello")
        assistant_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::Assistant) }
        expect(assistant_message).not_to be_nil
      end
    end

    context "without instructions" do
      let(:agent_class) do
        Class.new(described_class) do
          model "test/gpt-4o"
        end
      end

      it "does not add system message" do
        agent = agent_class.new
        agent.generate("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::System) }
        expect(system_message).to be_nil
      end
    end

    context "with invalid model format" do
      let(:agent_class) do
        Class.new(described_class) do
          model "invalid-format"
        end
      end

      it "raises error" do
        agent = agent_class.new
        expect { agent.generate("Hello") }.to raise_error(ArgumentError, /Model string must be in format/)
      end
    end

    context "with unknown provider" do
      let(:agent_class) do
        Class.new(described_class) do
          model "unknown/model"
        end
      end

      it "raises error" do
        agent = agent_class.new
        expect { agent.generate("Hello") }.to raise_error(ArgumentError, /Unknown provider/)
      end
    end
  end
end
