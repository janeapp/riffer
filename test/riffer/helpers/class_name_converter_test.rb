# frozen_string_literal: true

require "test_helper"

describe Riffer::Helpers::ClassNameConverter do
  let(:converter_class) do
    Class.new do
      extend Riffer::Helpers::ClassNameConverter
    end
  end

  describe "#class_name_to_path" do
    it "converts simple class name to snake_case" do
      result = converter_class.class_name_to_path("Agent")
      assert_equal "agent", result
    end

    it "converts namespaced class to path with slashes" do
      result = converter_class.class_name_to_path("Riffer::Agent")
      assert_equal "riffer/agent", result
    end

    it "converts multi-word class names to snake_case" do
      result = converter_class.class_name_to_path("MyTestAgent")
      assert_equal "my_test_agent", result
    end

    it "converts deeply nested namespaces" do
      result = converter_class.class_name_to_path("Riffer::Providers::OpenAI")
      assert_equal "riffer/providers/open_ai", result
    end

    it "handles consecutive capitals correctly" do
      result = converter_class.class_name_to_path("HTTPSConnection")
      assert_equal "https_connection", result
    end

    it "handles symbols" do
      result = converter_class.class_name_to_path(:"Riffer::Agent")
      assert_equal "riffer/agent", result
    end

    it "handles already snake_cased names" do
      result = converter_class.class_name_to_path("riffer/agent")
      assert_equal "riffer/agent", result
    end

    it "converts complex real-world example" do
      result = converter_class.class_name_to_path("Riffer::Messages::Assistant")
      assert_equal "riffer/messages/assistant", result
    end
  end
end
