# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::WebSearchDone do
  describe "#initialize" do
    it "sets the query" do
      event = Riffer::StreamEvents::WebSearchDone.new("ruby programming")
      expect(event.query).must_equal "ruby programming"
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::WebSearchDone.new("ruby programming")
      expect(event.role).must_equal :assistant
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::WebSearchDone.new("ruby programming", role: :user)
      expect(event.role).must_equal :user
    end

    it "sets sources to empty array by default" do
      event = Riffer::StreamEvents::WebSearchDone.new("ruby programming")
      expect(event.sources).must_equal []
    end

    it "sets sources when provided" do
      sources = [{title: "Example", url: "https://example.com"}]
      event = Riffer::StreamEvents::WebSearchDone.new("ruby programming", sources: sources)
      expect(event.sources).must_equal sources
    end
  end

  describe "#to_h" do
    it "returns hash with role, query, and sources" do
      event = Riffer::StreamEvents::WebSearchDone.new("ruby programming")
      expect(event.to_h).must_equal({role: :assistant, query: "ruby programming", sources: []})
    end

    it "includes sources in hash" do
      sources = [{title: "Example", url: "https://example.com"}]
      event = Riffer::StreamEvents::WebSearchDone.new("ruby programming", sources: sources)
      expect(event.to_h).must_equal({role: :assistant, query: "ruby programming", sources: sources})
    end
  end
end
