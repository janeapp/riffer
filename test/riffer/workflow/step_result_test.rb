# frozen_string_literal: true

require "test_helper"

describe Riffer::Workflow::StepResult do
  describe "success" do
    let(:result) do
      Riffer::Workflow::StepResult.new(
        status: :success,
        payload: {message: "hello"},
        output: {reply: "Hi"}
      )
    end

    it "is success" do
      expect(result.success?).must_equal true
    end

    it "is not failed" do
      expect(result.failed?).must_equal false
    end

    it "is not pending" do
      expect(result.pending?).must_equal false
    end

    it "carries the output" do
      expect(result.output).must_equal({reply: "Hi"})
    end

    it "carries the payload" do
      expect(result.payload).must_equal({message: "hello"})
    end

    it "has no error" do
      expect(result.error).must_be_nil
    end
  end

  describe "failed" do
    let(:error) { RuntimeError.new("connection lost") }
    let(:result) do
      Riffer::Workflow::StepResult.new(
        status: :failed,
        payload: {message: "hello"},
        error: error
      )
    end

    it "is failed" do
      expect(result.failed?).must_equal true
    end

    it "is not success" do
      expect(result.success?).must_equal false
    end

    it "carries the error" do
      expect(result.error).must_equal error
    end

    it "carries the payload" do
      expect(result.payload).must_equal({message: "hello"})
    end

    it "has no output" do
      expect(result.output).must_be_nil
    end
  end

  describe "pending" do
    let(:result) { Riffer::Workflow::StepResult.new(status: :pending) }

    it "is pending" do
      expect(result.pending?).must_equal true
    end

    it "has no payload" do
      expect(result.payload).must_be_nil
    end
  end

  describe "#to_h" do
    it "serializes a successful step" do
      result = Riffer::Workflow::StepResult.new(
        status: :success,
        payload: {text: "hi"},
        output: {text: "HI"}
      )
      expect(result.to_h).must_equal({status: :success, payload: {text: "hi"}, output: {text: "HI"}})
    end

    it "serializes a failed step" do
      result = Riffer::Workflow::StepResult.new(
        status: :failed,
        payload: {text: "hi"},
        error: RuntimeError.new("boom")
      )
      expect(result.to_h).must_equal({status: :failed, payload: {text: "hi"}, error: "boom"})
    end

    it "serializes a pending step" do
      result = Riffer::Workflow::StepResult.new(status: :pending)
      expect(result.to_h).must_equal({status: :pending})
    end
  end
end
