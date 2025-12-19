# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Base do
  describe "#initialize" do
    it "sets the agent name" do
      agent = described_class.new(name: "test_agent", model: "gpt-4", provider: "openai")
      expect(agent.name).to eq("test_agent")
    end

    it "sets the agent model" do
      agent = described_class.new(name: "test_agent", model: "gpt-4", provider: "openai")
      expect(agent.model).to eq("gpt-4")
    end

    it "sets the agent provider" do
      agent = described_class.new(name: "test_agent", model: "gpt-4", provider: "openai")
      expect(agent.provider).to eq("openai")
    end
  end

  describe "#call" do
    it "raises NotImplementedError" do
      agent = described_class.new(name: "test_agent", model: "gpt-4")
      expect { agent.call("test input") }.to raise_error(NotImplementedError)
    end
  end
end
