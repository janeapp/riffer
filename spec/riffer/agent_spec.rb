# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agent do
  subject(:agent_class) do
    Class.new(described_class) do
      model "test/gpt-4o"
      instructions "You are a helpful assistant."
    end
  end

  describe ".model" do
    it "sets the model" do
      expect(agent_class.model).to eq("test/gpt-4o")
    end
  end

  describe ".instructions" do
    it "sets the instructions" do
      expect(agent_class.instructions).to eq("You are a helpful assistant.")
    end

    it "raises error when instructions is not a string" do
      expect {
        Class.new(described_class) do
          instructions 123
        end
      }.to raise_error(ArgumentError, /instructions must be a String/)
    end
  end

  describe "#initialize" do
    it "initializes with empty messages" do
      agent = agent_class.new
      expect(agent.messages).to eq([])
    end
  end

  describe "#run" do
    context "with test provider" do
      it "returns a text response" do
        agent = agent_class.new
        result = agent.run("What is the weather?")
        expect(result).to be_a(String)
      end

      it "adds system message to messages when instructions are provided" do
        agent = agent_class.new
        agent.run("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::System) }
        expect(system_message).not_to be_nil
      end

      it "adds user message to messages" do
        agent = agent_class.new
        agent.run("Hello")
        user_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::User) }
        expect(user_message).not_to be_nil
      end

      it "adds assistant message to messages" do
        agent = agent_class.new
        agent.run("Hello")
        assistant_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::Assistant) }
        expect(assistant_message).not_to be_nil
      end
    end

    context "without instructions" do
      subject(:agent_class) do
        Class.new(described_class) do
          model "test/gpt-4o"
        end
      end

      it "does not add system message" do
        agent = agent_class.new
        agent.run("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::System) }
        expect(system_message).to be_nil
      end
    end

    context "with openai provider" do
      subject(:agent_class) do
        Class.new(described_class) do
          model "openai/gpt-4o"
          instructions "You are a helpful assistant."
        end
      end

      let(:original_api_key) { Riffer.config.openai_api_key }

      before do
        Riffer.config.openai_api_key = nil
      end

      after do
        Riffer.config.openai_api_key = original_api_key
      end

      it "raises error when API key is not configured" do
        agent = agent_class.new
        expect { agent.run("Hello") }.to raise_error(ArgumentError, /OpenAI API key is required/)
      end
    end

    context "with invalid model format" do
      subject(:agent_class) do
        Class.new(described_class) do
          model "invalid-format"
        end
      end

      it "raises error" do
        agent = agent_class.new
        expect { agent.run("Hello") }.to raise_error(ArgumentError, /Model string must be in format/)
      end
    end

    context "with unknown provider" do
      subject(:agent_class) do
        Class.new(described_class) do
          model "unknown/model"
        end
      end

      it "raises error" do
        agent = agent_class.new
        expect { agent.run("Hello") }.to raise_error(ArgumentError, /Unknown provider/)
      end
    end
  end
end
