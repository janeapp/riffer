# frozen_string_literal: true

require "test_helper"

describe Riffer::Messages::Tool do
  describe "#role" do
    it "returns tool" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
      expect(message.role).must_equal "tool"
    end
  end

  describe "#to_h" do
    it "returns hash with role, content, tool_call_id, and name" do
      message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
      expected = {role: "tool", content: "Result", tool_call_id: "123", name: "my_tool"}
      expect(message.to_h).must_equal expected
    end
  end

  describe "#initialize" do
    describe "validation" do
      it "raises InvalidInputError when tool_call_id is nil" do
        error = expect {
          Riffer::Messages::Tool.new("Result", tool_call_id: nil, name: "my_tool")
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_match(/tool_call_id is required/)
      end

      it "raises InvalidInputError when tool_call_id is empty" do
        error = expect {
          Riffer::Messages::Tool.new("Result", tool_call_id: "", name: "my_tool")
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_match(/tool_call_id is required/)
      end

      it "raises InvalidInputError when name is nil" do
        error = expect {
          Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: nil)
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_match(/name is required/)
      end

      it "raises InvalidInputError when name is empty" do
        error = expect {
          Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "")
        }.must_raise(Riffer::Messages::InvalidInputError)
        expect(error.message).must_match(/name is required/)
      end

      it "accepts valid tool_call_id and name" do
        message = Riffer::Messages::Tool.new("Result", tool_call_id: "123", name: "my_tool")
        expect(message.tool_call_id).must_equal "123"
        expect(message.name).must_equal "my_tool"
      end
    end
  end
end
