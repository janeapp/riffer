# frozen_string_literal: true

require "test_helper"

describe Riffer::Providers::Gemini::Client do
  let(:path) { "v1beta/models/gemini-3.5-flash-lite:generateContent" }
  let(:url) { "https://generativelanguage.googleapis.com/#{path}" }
  let(:client) { Riffer::Providers::Gemini::Client.new(api_key: "test_api_key") }

  describe "#post" do
    it "returns the parsed response body with symbol keys" do
      stub_request(:post, url).to_return(status: 200, body: '{"candidates":[]}')

      expect(client.post(path, { contents: [] })).must_equal({ candidates: [] })
    end

    it "sends the api key header and JSON body" do
      stub = stub_request(:post, url).
        with(
          headers: { "x-goog-api-key" => "test_api_key", "Content-Type" => "application/json" },
          body: '{"contents":[]}',
        ).
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

    it "sends the passed headers" do
      stub = stub_request(:post, url).
        with(headers: { "x-goog-api-key" => "test_api_key", "x-goog-user-project" => "my-project" }).
        to_return(status: 200, body: "{}")
      headers = { "x-goog-user-project" => "my-project" }
      Riffer::Providers::Gemini::Client.new(api_key: "test_api_key", headers: headers).post(path, { contents: [] })

      assert_requested stub
    end

    it "ignores a trailing slash on base_url" do
      stub = stub_request(:post, "http://localhost:8080/#{path}").to_return(status: 200, body: "{}")
      custom = Riffer::Providers::Gemini::Client.new(api_key: "k", base_url: "http://localhost:8080/")
      custom.post(path, { contents: [] })

      assert_requested stub
    end

    it "raises Riffer::APIError with the status, body and API message on a failing status" do
      stub_request(:post, url).to_return(status: 400, body: '{"error":{"message":"bad request"}}')
      error = expect { client.post(path, { contents: [] }) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Gemini API error (400): bad request"
      expect(error.status).must_equal 400
      expect(error.body).must_equal '{"error":{"message":"bad request"}}'
    end

    it "raises Riffer::APIError with the raw body when the error is not JSON" do
      stub_request(:post, url).to_return(status: 500, body: "boom")
      error = expect { client.post(path, { contents: [] }) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Gemini API error (500): boom"
    end
  end

  describe "#post_stream" do
    let(:stream_path) { "v1beta/models/gemini-3.5-flash-lite:streamGenerateContent?alt=sse" }
    let(:stream_url) { "https://generativelanguage.googleapis.com/#{stream_path}" }

    it "yields the response body chunks" do
      stub_request(:post, stream_url).to_return(status: 200, body: "data: {}\n\n")
      chunks = []
      client.post_stream(stream_path, { contents: [] }) { |chunk| chunks << chunk }

      expect(chunks.join).must_equal "data: {}\n\n"
    end

    it "raises Riffer::APIError on a failing status without yielding the body" do
      stub_request(:post, stream_url).to_return(status: 403, body: '{"error":{"message":"denied"}}')
      chunks = []
      error = expect do
        client.post_stream(stream_path, { contents: [] }) { |chunk| chunks << chunk }
      end.must_raise Riffer::APIError

      expect(error.message).must_equal "Gemini API error (403): denied"
      expect(chunks).must_be_empty
    end
  end
end
