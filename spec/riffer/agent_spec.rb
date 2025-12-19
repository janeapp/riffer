# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agent do
  describe "DSL methods" do
    let(:test_agent_class) do
      Class.new(described_class) do
        provider :test
        model "gpt-4o"
        instructions "You are a helpful assistant."
      end
    end

    describe ".provider" do
      it "sets the provider" do
        expect(test_agent_class.provider).to eq(:test)
      end
    end

    describe ".model" do
      it "sets the model" do
        expect(test_agent_class.model).to eq("gpt-4o")
      end
    end

    describe ".instructions" do
      it "sets the instructions" do
        expect(test_agent_class.instructions).to eq("You are a helpful assistant.")
      end
    end
  end

  describe "#initialize" do
    let(:test_agent_class) do
      Class.new(described_class) do
        provider :test
        model "gpt-4o"
        instructions "You are a helpful assistant."
      end
    end

    it "initializes with empty messages" do
      agent = test_agent_class.new
      expect(agent.messages).to eq([])
    end
  end

  describe "#run" do
    context "with test provider" do
      let(:test_agent_class) do
        Class.new(described_class) do
          provider :test
          model "gpt-4o"
          instructions "You are a helpful assistant."
        end
      end

      it "returns a text response" do
        agent = test_agent_class.new
        result = agent.run("What is the weather?")
        expect(result).to be_a(String)
      end

      it "adds system message to messages when instructions are provided" do
        agent = test_agent_class.new
        agent.run("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::System) }
        expect(system_message).not_to be_nil
      end

      it "adds user message to messages" do
        agent = test_agent_class.new
        agent.run("Hello")
        user_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::User) }
        expect(user_message).not_to be_nil
      end

      it "adds assistant message to messages" do
        agent = test_agent_class.new
        agent.run("Hello")
        assistant_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::Assistant) }
        expect(assistant_message).not_to be_nil
      end
    end

    context "without instructions" do
      let(:test_agent_class) do
        Class.new(described_class) do
          provider :test
          model "gpt-4o"
        end
      end

      it "does not add system message" do
        agent = test_agent_class.new
        agent.run("Hello")
        system_message = agent.messages.find { |msg| msg.is_a?(Riffer::Agents::Messages::System) }
        expect(system_message).to be_nil
      end
    end

    context "with openai provider" do
      let(:openai_agent_class) do
        Class.new(described_class) do
          provider :openai
          model "gpt-4o"
          instructions "You are a helpful assistant."
        end
      end

      it "raises error when OPENAI_API_KEY is not set" do
        stub_const("ENV", {})
        agent = openai_agent_class.new
        expect { agent.run("Hello") }.to raise_error(ArgumentError, /OPENAI_API_KEY/)
      end
    end

    context "with unknown provider" do
      let(:unknown_provider_agent_class) do
        Class.new(described_class) do
          provider :unknown
          model "gpt-4o"
        end
      end

      it "raises error" do
        agent = unknown_provider_agent_class.new
        expect { agent.run("Hello") }.to raise_error(ArgumentError, /Unknown provider/)
      end
    end
  end
end
