# frozen_string_literal: true

require "test_helper"

# Named container so classes assigned beneath it get permanent names; each test
# removes the constants it creates (the classes stay named — that's fine).
module IdentifierTestNamespace; end

describe Riffer::Helpers::Identifier do
  let(:helper) { Riffer::Helpers::Identifier }

  after do
    IdentifierTestNamespace.constants.each do |const|
      IdentifierTestNamespace.send(:remove_const, const)
    end
  end

  describe ".derive" do
    it "converts simple class name to snake_case" do
      result = helper.derive("Agent")

      expect(result).must_equal "agent"
    end

    it "converts namespaced class to forward slash format" do
      result = helper.derive("Riffer::Agent")

      expect(result).must_equal "riffer/agent"
    end

    it "converts multi-word class names to snake_case" do
      result = helper.derive("MyTestAgent")

      expect(result).must_equal "my_test_agent"
    end

    it "converts deeply nested namespaces" do
      result = helper.derive("Riffer::Providers::OpenAI")

      expect(result).must_equal "riffer/providers/open_ai"
    end

    it "handles consecutive capitals correctly" do
      result = helper.derive("HTTPSConnection")

      expect(result).must_equal "https_connection"
    end

    it "handles already snake_cased names with forward slashes" do
      result = helper.derive("riffer/agent")

      expect(result).must_equal "riffer/agent"
    end

    it "converts complex real-world example" do
      result = helper.derive("Riffer::Messages::Assistant")

      expect(result).must_equal "riffer/messages/assistant"
    end

    it "returns an empty string for nil" do
      result = helper.derive(nil)

      expect(result).must_equal ""
    end
  end

  describe ".for" do
    it "derives the identifier from the class name" do
      klass = IdentifierTestNamespace.const_set(:MyTestTool, Class.new)

      expect(helper.for(klass)).must_equal "identifier_test_namespace/my_test_tool"
    end

    it "memoizes the derived identifier on the class" do
      klass = IdentifierTestNamespace.const_set(:MemoizedClass, Class.new)

      first = helper.for(klass)

      expect(klass.instance_variable_get(:@derived_identifier)).must_equal first
      expect(helper.for(klass)).must_be_same_as first
    end

    it "returns an empty string for anonymous classes without caching" do
      klass = Class.new

      expect(helper.for(klass)).must_equal ""
      expect(klass.instance_variable_get(:@derived_identifier)).must_be_nil
    end

    it "derives and caches the real identifier once an anonymous class is named" do
      klass = Class.new

      expect(helper.for(klass)).must_equal ""

      IdentifierTestNamespace.const_set(:LaterNamed, klass)

      expect(helper.for(klass)).must_equal "identifier_test_namespace/later_named"
      expect(klass.instance_variable_get(:@derived_identifier)).must_equal "identifier_test_namespace/later_named"
    end

    it "uses the real class-path name even when the class shadows Module#name" do
      klass = IdentifierTestNamespace.const_set(:ShadowedTool, Class.new(Riffer::Tool) { identifier "shadowed" })

      expect(helper.for(klass)).must_equal "identifier_test_namespace/shadowed_tool"
    end
  end
end
