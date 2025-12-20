# frozen_string_literal: true

require "spec_helper"

RSpec.describe Riffer::Tools::Base do
  let(:tool_class) do
    Class.new(described_class) do
      id "test_tool"
      description "A test tool"
      parameters({
        type: "object",
        properties: {
          location: {type: "string", description: "The location"}
        },
        required: ["location"]
      })

      def execute(location:)
        "Result for #{location}"
      end
    end
  end

  describe ".id" do
    it "sets the tool id" do
      expect(tool_class.id).to eq("test_tool")
    end

    it "raises error when id is not a string" do
      expect {
        Class.new(described_class) do
          id 123
        end
      }.to raise_error(ArgumentError, /id must be a String/)
    end

    it "raises error when id is an empty string" do
      expect {
        Class.new(described_class) do
          id "   "
        end
      }.to raise_error(ArgumentError, /id cannot be empty/)
    end
  end

  describe ".description" do
    it "sets the tool description" do
      expect(tool_class.description).to eq("A test tool")
    end

    it "raises error when description is not a string" do
      expect {
        Class.new(described_class) do
          description 123
        end
      }.to raise_error(ArgumentError, /description must be a String/)
    end

    it "raises error when description is an empty string" do
      expect {
        Class.new(described_class) do
          description "   "
        end
      }.to raise_error(ArgumentError, /description cannot be empty/)
    end
  end

  describe ".parameters" do
    it "sets the tool parameters" do
      params = tool_class.parameters
      expect(params[:type]).to eq("object")
    end

    it "includes properties in parameters" do
      params = tool_class.parameters
      expect(params[:properties][:location][:type]).to eq("string")
    end

    it "raises error when parameters is not a hash" do
      expect {
        Class.new(described_class) do
          parameters "invalid"
        end
      }.to raise_error(ArgumentError, /parameters must be a Hash/)
    end
  end

  describe "#execute" do
    it "raises NotImplementedError for base class" do
      tool = described_class.new
      expect { tool.execute }.to raise_error(NotImplementedError)
    end

    it "can be implemented by subclasses" do
      tool = tool_class.new
      result = tool.execute(location: "San Francisco")
      expect(result).to eq("Result for San Francisco")
    end
  end

  describe "#schema" do
    it "includes the tool id in schema" do
      tool = tool_class.new
      schema = tool.schema
      expect(schema[:name]).to eq("test_tool")
    end

    it "includes the tool description in schema" do
      tool = tool_class.new
      schema = tool.schema
      expect(schema[:description]).to eq("A test tool")
    end

    it "includes the tool parameters in schema" do
      tool = tool_class.new
      schema = tool.schema
      expect(schema[:parameters][:type]).to eq("object")
    end
  end

  describe "#to_openai_tool" do
    it "returns OpenAI-compatible tool format" do
      tool = tool_class.new
      openai_tool = tool.to_openai_tool

      expect(openai_tool[:type]).to eq("function")
    end

    it "includes function name in OpenAI format" do
      tool = tool_class.new
      openai_tool = tool.to_openai_tool

      expect(openai_tool[:function][:name]).to eq("test_tool")
    end

    it "includes function description in OpenAI format" do
      tool = tool_class.new
      openai_tool = tool.to_openai_tool

      expect(openai_tool[:function][:description]).to eq("A test tool")
    end

    it "includes function parameters in OpenAI format" do
      tool = tool_class.new
      openai_tool = tool.to_openai_tool

      expect(openai_tool[:function][:parameters][:type]).to eq("object")
    end
  end
end
