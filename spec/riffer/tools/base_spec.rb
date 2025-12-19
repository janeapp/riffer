# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Tools::Base do
  describe "#initialize" do
    it "creates a tool with name and description" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
      expect(tool.name).to eq("test_tool")
      expect(tool.description).to eq("A test tool")
    end
  end

  describe "#call" do
    it "raises NotImplementedError" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
      expect { tool.call }.to raise_error(NotImplementedError)
    end
  end

  describe "#schema" do
    it "returns a schema hash" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
      schema = tool.schema
      expect(schema[:name]).to eq("test_tool")
      expect(schema[:description]).to eq("A test tool")
      expect(schema[:parameters]).to eq({})
    end
  end
end
