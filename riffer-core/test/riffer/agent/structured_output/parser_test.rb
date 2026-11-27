# frozen_string_literal: true

require "test_helper"

describe Riffer::Agent::StructuredOutput::Parser do
  def parse(content)
    Riffer::Agent::StructuredOutput::Parser.parse(content)
  end

  describe ".parse" do
    it "parses plain JSON with symbolized keys" do
      expect(parse('{"sentiment":"positive"}')).must_equal({ sentiment: "positive" })
    end

    it "returns nil for JSON that is not an object" do
      expect(parse("[1, 2]")).must_be_nil
    end

    it "returns nil for a top-level array of objects" do
      expect(parse(%([{"sentiment":"neutral"},{"sentiment":"positive"}]))).must_be_nil
    end

    it "recovers an object from a json code fence" do
      expect(parse("```json\n{\"sentiment\":\"positive\"}\n```")).must_equal({ sentiment: "positive" })
    end

    it "recovers an object from a bare code fence" do
      expect(parse("```\n{\"sentiment\":\"positive\"}\n```")).must_equal({ sentiment: "positive" })
    end

    it "recovers an object after leading prose" do
      expect(parse('Here is the extracted data: {"sentiment":"positive"}')).must_equal({ sentiment: "positive" })
    end

    it "recovers an object before trailing prose" do
      content = '{"sentiment":"positive"} Let me know if you need anything else.'

      expect(parse(content)).must_equal({ sentiment: "positive" })
    end

    it "recovers an object wrapped in markdown formatting" do
      expect(parse('**{"sentiment":"positive"}**')).must_equal({ sentiment: "positive" })
    end

    it "recovers a nested object whole" do
      content = 'Result: {"name":"John","address":{"city":"Toronto"}}'

      expect(parse(content)).must_equal({ name: "John", address: { city: "Toronto" } })
    end

    it "ignores braces and escaped quotes inside string values" do
      content = 'Sure: {"note":"a } and a { and a \\"quoted\\" }"} done'

      expect(parse(content)).must_equal({ note: 'a } and a { and a "quoted" }' })
    end

    it "recovers an object surrounded by multibyte prose" do
      expect(parse('Voilà : {"ville":"Montréal"} — merci')).must_equal({ ville: "Montréal" })
    end

    it "returns nil when prose around the object contains braces" do
      expect(parse('Filling in the {template}: {"sentiment":"positive"}')).must_be_nil
    end

    it "returns nil when the reply contains several objects" do
      expect(parse('Draft: {"sentiment":"neutral"} Final: {"sentiment":"positive"}')).must_be_nil
    end

    it "returns nil when no object is present" do
      expect(parse("I could not determine the sentiment.")).must_be_nil
    end

    it "returns nil when the only object is malformed" do
      expect(parse('Here: {"sentiment":"positive",}')).must_be_nil
    end

    it "does not recover a nested object from a malformed outer object" do
      expect(parse('{"outer": {"sentiment":"positive"}, broken}')).must_be_nil
    end
  end

  describe ".extract" do
    def extract(content)
      Riffer::Agent::StructuredOutput::Parser.extract(content)
    end

    it "returns plain JSON unchanged alongside the object" do
      expect(extract('{"sentiment":"positive"}')).must_equal ['{"sentiment":"positive"}', { sentiment: "positive" }]
    end

    it "returns the JSON text without a surrounding code fence" do
      content = "```json\n{\"sentiment\":\"positive\"}\n```"

      expect(extract(content)).must_equal ['{"sentiment":"positive"}', { sentiment: "positive" }]
    end

    it "returns the JSON text without surrounding prose" do
      content = 'Here is the data: {"sentiment":"positive"} Let me know.'

      expect(extract(content)).must_equal ['{"sentiment":"positive"}', { sentiment: "positive" }]
    end

    it "returns nil when no object is present" do
      expect(extract("I could not determine the sentiment.")).must_be_nil
    end
  end
end
