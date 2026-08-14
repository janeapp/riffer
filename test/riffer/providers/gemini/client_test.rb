# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Gemini::Client do
  let(:path) { "v1beta/models/gemini-2.5-flash-lite:generateContent" }
  let(:url) { "https://generativelanguage.googleapis.com/#{path}" }
  let(:client) { Riffer::Providers::Gemini::Client.new(api_key: "test_api_key") }

  describe "#initialize" do
    it "uses default timeouts" do
      expect(client.instance_variable_get(:@open_timeout)).must_equal 10
      expect(client.instance_variable_get(:@read_timeout)).must_equal 60
    end

    it "allows custom timeouts" do
      custom = Riffer::Providers::Gemini::Client.new(api_key: "k", open_timeout: 5, read_timeout: 30, write_timeout: 15)

      expect(custom.instance_variable_get(:@open_timeout)).must_equal 5
      expect(custom.instance_variable_get(:@read_timeout)).must_equal 30
      expect(custom.instance_variable_get(:@write_timeout)).must_equal 15
    end
  end

  describe "#post" do
    it "returns the parsed response body with symbol keys" do
      stub_request(:post, url).to_return(status: 200, body: '{"candidates":[]}')

      expect(client.post(path, { contents: [] })).must_equal({ candidates: [] })
    end

    it "sends the api key header and JSON body" do
      stub = stub_request(:post, url).
        with(headers: { "x-goog-api-key" => "test_api_key", "Content-Type" => "application/json" }).
        to_return(status: 200, body: "{}")
      client.post(path, { contents: [] })

      assert_requested stub
    end

    it "honors a custom base_url" do
      stub = stub_request(:post, "http://localhost:8080/#{path}").to_return(status: 200, body: "{}")
      custom = Riffer::Providers::Gemini::Client.new(api_key: "k", base_url: "http://localhost:8080")
      custom.post(path, { contents: [] })

      assert_requested stub
    end

    it "raises Riffer::Error with the API message on a failing status" do
      stub_request(:post, url).to_return(status: 400, body: '{"error":{"message":"bad request"}}')
      error = expect { client.post(path, { contents: [] }) }.must_raise Riffer::Error

      expect(error.message).must_equal "Gemini API error (400): bad request"
    end

    it "raises Riffer::Error with the raw body when the error is not JSON" do
      stub_request(:post, url).to_return(status: 500, body: "boom")
      error = expect { client.post(path, { contents: [] }) }.must_raise Riffer::Error

      expect(error.message).must_equal "Gemini API error (500): boom"
    end
  end

  describe "#post_stream" do
    let(:stream_path) { "v1beta/models/gemini-2.5-flash-lite:streamGenerateContent?alt=sse" }
    let(:stream_url) { "https://generativelanguage.googleapis.com/#{stream_path}" }

    it "yields the response body chunks" do
      stub_request(:post, stream_url).to_return(status: 200, body: "data: {}\n\n")
      chunks = []
      client.post_stream(stream_path, { contents: [] }) { |chunk| chunks << chunk }

      expect(chunks.join).must_equal "data: {}\n\n"
    end

    it "raises Riffer::Error on a failing status" do
      stub_request(:post, stream_url).to_return(status: 403, body: '{"error":{"message":"denied"}}')

      expect { client.post_stream(stream_path, { contents: [] }) { |_c| } }.must_raise Riffer::Error
    end
  end
end
