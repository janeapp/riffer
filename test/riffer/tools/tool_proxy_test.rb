# frozen_string_literal: true

require "test_helper"

describe Riffer::Tools::ToolProxy do
  describe "#name" do
    it "returns the name" do
      proxy = Riffer::Tools::ToolProxy.new(name: "weather", description: "Gets weather")
      expect(proxy.name).must_equal "weather"
    end
  end

  describe "#description" do
    it "returns the description" do
      proxy = Riffer::Tools::ToolProxy.new(name: "weather", description: "Gets weather")
      expect(proxy.description).must_equal "Gets weather"
    end
  end

  describe "#parameters_schema" do
    it "defaults to the empty object schema" do
      proxy = Riffer::Tools::ToolProxy.new(name: "weather", description: "Gets weather")
      expected = {type: "object", properties: {}, required: [], additionalProperties: false}
      expect(proxy.parameters_schema).must_equal expected
    end

    it "accepts a custom schema" do
      schema = {type: "object", properties: {city: {type: "string"}}, required: ["city"], additionalProperties: false}
      proxy = Riffer::Tools::ToolProxy.new(name: "weather", description: "Gets weather", parameters_schema: schema)
      expect(proxy.parameters_schema).must_equal schema
    end
  end
end
