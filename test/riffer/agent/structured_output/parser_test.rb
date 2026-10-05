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

    it "returns non-object JSON as parsed" do
      expect(parse("[1, 2]")).must_equal [1, 2]
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

    it "skips a balanced non-JSON brace span in prose before the object" do
      content = 'Filling in the {template}: {"sentiment":"positive"}'

      expect(parse(content)).must_equal({ sentiment: "positive" })
    end

    it "skips an unmatched brace in prose before the object" do
      content = 'Use { to open: {"sentiment":"positive"}'

      expect(parse(content)).must_equal({ sentiment: "positive" })
    end

    it "recovers the first object when the reply contains several" do
      content = 'Draft: {"sentiment":"neutral"} Final: {"sentiment":"positive"}'

      expect(parse(content)).must_equal({ sentiment: "neutral" })
    end

    it "recovers an object surrounded by multibyte prose and braces" do
      content = 'Voilà le {modèle} : {"ville":"Montréal"} — {fin}'

      expect(parse(content)).must_equal({ ville: "Montréal" })
    end

    it "rejects many unmatched braces before long prose" do
      content = ("{ " * 25) + ("lorem ipsum " * 8_000)

      expect { parse(content) }.must_raise JSON::ParserError
    end

    it "raises the strict parse error when no object is present" do
      error = expect { parse("I could not determine the sentiment.") }.must_raise JSON::ParserError
      strict_error = expect { JSON.parse("I could not determine the sentiment.") }.must_raise JSON::ParserError

      expect(error.message).must_equal strict_error.message
    end

    it "raises when the only object is malformed" do
      expect { parse('Here: {"sentiment":"positive",}') }.must_raise JSON::ParserError
    end

    it "does not recover a nested object from a malformed outer object" do
      expect { parse('{"outer": {"sentiment":"positive"}, broken}') }.must_raise JSON::ParserError
    end

    it "stops after a bounded number of candidates" do
      strays = "{" * Riffer::Agent::StructuredOutput::Parser::MAX_CANDIDATES
      content = "#{strays}{\"sentiment\":\"positive\"}"

      expect { parse(content) }.must_raise JSON::ParserError
    end
  end
end
