# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::Base do
  describe "#initialize" do
    it "sets the tool name" do
      tool = Riffer::Tools::Base.new(name: "test_tool", description: "A test tool")
      expect(tool.name).must_equal "test_tool"
    end

    it "sets the tool description" do
      tool = Riffer::Tools::Base.new(name: "test_tool", description: "A test tool")
      expect(tool.description).must_equal "A test tool"
    end
  end

  describe "#call" do
    it "raises NotImplementedError" do
      tool = Riffer::Tools::Base.new(name: "test_tool", description: "A test tool")
      expect { tool.call }.must_raise(NotImplementedError)
    end
  end

  describe "#schema" do
    it "includes the tool name in schema" do
      tool = Riffer::Tools::Base.new(name: "test_tool", description: "A test tool")
      schema = tool.schema
      expect(schema[:name]).must_equal "test_tool"
    end

    it "includes the tool description in schema" do
      tool = Riffer::Tools::Base.new(name: "test_tool", description: "A test tool")
      schema = tool.schema
      expect(schema[:description]).must_equal "A test tool"
    end

    it "includes empty parameters in schema" do
      tool = Riffer::Tools::Base.new(name: "test_tool", description: "A test tool")
      schema = tool.schema
      expect(schema[:parameters]).must_equal({})
    end
  end
end
