# frozen_string_literal: true

require "test_helper"

describe Riffer::StreamEvents::WebSearchStatus do
  describe "#initialize" do
    it "sets the status" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching")
      expect(event.status).must_equal "searching"
    end

    it "sets default role to assistant" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching")
      expect(event.role).must_equal :assistant
    end

    it "allows setting custom role" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching", role: :user)
      expect(event.role).must_equal :user
    end

    it "sets url to nil by default" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching")
      expect(event.url).must_be_nil
    end

    it "sets url when provided" do
      event = Riffer::StreamEvents::WebSearchStatus.new("open_page", url: "https://example.com")
      expect(event.url).must_equal "https://example.com"
    end

    it "sets query to nil by default" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching")
      expect(event.query).must_be_nil
    end

    it "sets query when provided" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching", query: "latest Ruby version")
      expect(event.query).must_equal "latest Ruby version"
    end
  end

  describe "#to_h" do
    it "returns hash with role and status" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching")
      expect(event.to_h).must_equal({role: :assistant, status: "searching"})
    end

    it "includes url when present" do
      event = Riffer::StreamEvents::WebSearchStatus.new("open_page", url: "https://example.com")
      expect(event.to_h).must_equal({role: :assistant, status: "open_page", url: "https://example.com"})
    end

    it "omits url when nil" do
      event = Riffer::StreamEvents::WebSearchStatus.new("in_progress")
      expect(event.to_h.key?(:url)).must_equal false
    end

    it "includes query when present" do
      event = Riffer::StreamEvents::WebSearchStatus.new("searching", query: "latest Ruby version")
      expect(event.to_h).must_equal({role: :assistant, status: "searching", query: "latest Ruby version"})
    end

    it "omits query when nil" do
      event = Riffer::StreamEvents::WebSearchStatus.new("in_progress")
      expect(event.to_h.key?(:query)).must_equal false
    end
  end
end
