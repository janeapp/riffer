# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Tools::Base do
  describe "#initialize" do
    it "sets the tool name" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
      expect(tool.name).to eq("test_tool")
    end

    it "sets the tool description" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
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
    it "includes the tool name in schema" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
      schema = tool.schema
      expect(schema[:name]).to eq("test_tool")
    end

    it "includes the tool description in schema" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
      schema = tool.schema
      expect(schema[:description]).to eq("A test tool")
    end

    it "includes empty parameters in schema" do
      tool = described_class.new(name: "test_tool", description: "A test tool")
      schema = tool.schema
      expect(schema[:parameters]).to eq({})
    end
  end
end
