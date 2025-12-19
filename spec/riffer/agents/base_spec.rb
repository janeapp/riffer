# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Agents::Base do
  describe "#initialize" do
    it "creates an agent with name, model, and provider" do
      agent = described_class.new(name: "test_agent", model: "gpt-4", provider: "openai")
      expect(agent.name).to eq("test_agent")
      expect(agent.model).to eq("gpt-4")
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
