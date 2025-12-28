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

    describe "validation" do
      it "raises ArgumentError when name is nil" do
        error = expect {
          Riffer::Tools::Base.new(name: nil, description: "A test tool")
        }.must_raise(ArgumentError)
        expect(error.message).must_match(/name is required/)
      end

      it "raises ArgumentError when name is empty" do
        error = expect {
          Riffer::Tools::Base.new(name: "", description: "A test tool")
        }.must_raise(ArgumentError)
        expect(error.message).must_match(/name is required/)
      end

      it "raises ArgumentError when description is nil" do
        error = expect {
          Riffer::Tools::Base.new(name: "test_tool", description: nil)
        }.must_raise(ArgumentError)
        expect(error.message).must_match(/description is required/)
      end

      it "raises ArgumentError when description is empty" do
        error = expect {
          Riffer::Tools::Base.new(name: "test_tool", description: "")
        }.must_raise(ArgumentError)
        expect(error.message).must_match(/description is required/)
      end

      it "accepts valid name and description" do
        tool = Riffer::Tools::Base.new(name: "test_tool", description: "A test tool")
        expect(tool.name).must_equal "test_tool"
        expect(tool.description).must_equal "A test tool"
      end
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
