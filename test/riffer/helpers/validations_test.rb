# frozen_string_literal: true

require "test_helper"

describe Riffer::Helpers::Validations do
  let(:validator) do
    Class.new do
      include Riffer::Helpers::Validations
    end.new
  end

  describe "#validate_is_string!" do
    it "returns true for valid non-empty strings" do
      assert validator.validate_is_string!("hello")
    end

    it "returns true for strings with whitespace" do
      assert validator.validate_is_string!("  hello world  ")
    end

    it "raises ArgumentError when value is not a string" do
      error = assert_raises(Riffer::ArgumentError) do
        validator.validate_is_string!(123)
      end
      assert_equal "value must be a String", error.message
    end

    it "raises ArgumentError for nil" do
      error = assert_raises(Riffer::ArgumentError) do
        validator.validate_is_string!(nil)
      end
      assert_equal "value must be a String", error.message
    end

    it "raises ArgumentError for empty strings" do
      error = assert_raises(Riffer::ArgumentError) do
        validator.validate_is_string!("")
      end
      assert_equal "value cannot be empty", error.message
    end

    it "raises ArgumentError for strings with only whitespace" do
      error = assert_raises(Riffer::ArgumentError) do
        validator.validate_is_string!("   ")
      end
      assert_equal "value cannot be empty", error.message
    end

    it "uses custom name in error message for type validation" do
      error = assert_raises(Riffer::ArgumentError) do
        validator.validate_is_string!([], "my_param")
      end
      assert_equal "my_param must be a String", error.message
    end

    it "uses custom name in error message for empty validation" do
      error = assert_raises(Riffer::ArgumentError) do
        validator.validate_is_string!("", "my_param")
      end
      assert_equal "my_param cannot be empty", error.message
    end

    it "accepts strings with special characters" do
      assert validator.validate_is_string!("hello!@#$%^&*()")
    end

    it "accepts strings with numbers" do
      assert validator.validate_is_string!("hello123")
    end

    it "accepts strings with newlines" do
      assert validator.validate_is_string!("hello\nworld")
    end
  end
end
