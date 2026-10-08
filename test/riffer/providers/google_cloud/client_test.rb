# frozen_string_literal: true

require "test_helper"
require "async"
require "async/barrier"

describe Riffer::Providers::GoogleCloud::Client do
  # Mimics googleauth's BaseClient#apply!: refreshes only a missing token, and
  # the refresh yields to the scheduler like a real metadata-server call.
  let(:credentials_class) do
    Class.new do
      attr_reader :refreshes

      def initialize(refresh_delay: 0)
        @refresh_delay = refresh_delay
        @refreshes = 0
        @token = nil
      end

      def expire!
        @token = nil
      end

      def apply!(hash)
        if @token.nil?
          sleep @refresh_delay
          @refreshes += 1
          @token = "token-#{@refreshes}"
        end
        hash[:authorization] = "Bearer #{@token}"
      end
    end
  end

  let(:credentials) { credentials_class.new }
  let(:client) do
    Riffer::Providers::GoogleCloud::Client.new(project_id: "my-project", location: "global", credentials: credentials)
  end
  let(:path) { "publishers/google/models/gemini-2.5-flash-lite:generateContent" }
  let(:url) do
    "https://aiplatform.googleapis.com/v1/projects/my-project/locations/global/#{path}"
  end

  describe ".base_url_for" do
    it "uses the global endpoint for the global location" do
      expect(Riffer::Providers::GoogleCloud::Client.base_url_for(location: "global")).
        must_equal "https://aiplatform.googleapis.com"
    end

    it "uses the multi-region endpoints for us and eu" do
      urls = %w[us eu].map { |location| Riffer::Providers::GoogleCloud::Client.base_url_for(location: location) }

      expect(urls).must_equal %w[https://aiplatform.us.rep.googleapis.com https://aiplatform.eu.rep.googleapis.com]
    end

    it "uses the regional endpoint for any other location" do
      expect(Riffer::Providers::GoogleCloud::Client.base_url_for(location: "europe-west4")).
        must_equal "https://europe-west4-aiplatform.googleapis.com"
    end
  end

  describe "#initialize" do
    it "uses default timeouts" do
      expect(client.instance_variable_get(:@open_timeout)).must_equal 10
      expect(client.instance_variable_get(:@read_timeout)).must_equal 60
    end

    it "rejects a location that is not a plain location id" do
      expect do
        Riffer::Providers::GoogleCloud::Client.new(project_id: "p", location: "evil.com/x", credentials: credentials)
      end.must_raise Riffer::ArgumentError
    end

    it "rejects a project id that is not a plain project id" do
      expect do
        Riffer::Providers::GoogleCloud::Client.new(project_id: "p/../q", location: "global", credentials: credentials)
      end.must_raise Riffer::ArgumentError
    end

    it "rejects a missing project id" do
      expect do
        Riffer::Providers::GoogleCloud::Client.new(project_id: nil, location: "global", credentials: credentials)
      end.must_raise Riffer::ArgumentError
    end
  end

  describe "#post" do
    it "returns the parsed response body with symbol keys" do
      stub_request(:post, url).to_return(status: 200, body: '{"candidates":[]}')

      expect(client.post(path, { contents: [] })).must_equal({ candidates: [] })
    end

    it "sends the bearer token and JSON body" do
      stub = stub_request(:post, url).
        with(
          headers: { "Authorization" => "Bearer token-1", "Content-Type" => "application/json" },
          body: '{"contents":[]}',
        ).
        to_return(status: 200, body: "{}")
      client.post(path, { contents: [] })

      assert_requested stub
    end

    it "addresses the regional endpoint and location for a regional client" do
      stub = stub_request(
        :post,
        "https://us-central1-aiplatform.googleapis.com/v1/projects/my-project/locations/us-central1/#{path}",
      ).to_return(status: 200, body: "{}")
      regional = Riffer::Providers::GoogleCloud::Client.new(
        project_id: "my-project", location: "us-central1", credentials: credentials,
      )
      regional.post(path, {})

      assert_requested stub
    end

    it "honors a custom base_url" do
      stub = stub_request(:post, "http://localhost:8080/v1/projects/my-project/locations/global/#{path}").
        to_return(status: 200, body: "{}")
      custom = Riffer::Providers::GoogleCloud::Client.new(
        project_id: "my-project", location: "global", credentials: credentials, base_url: "http://localhost:8080",
      )
      custom.post(path, {})

      assert_requested stub
    end

    it "reuses a fresh token across requests" do
      stub_request(:post, url).to_return(status: 200, body: "{}")
      2.times { client.post(path, {}) }

      expect(credentials.refreshes).must_equal 1
    end

    it "refreshes an expired token" do
      stub = stub_request(:post, url).with(headers: { "Authorization" => "Bearer token-2" }).
        to_return(status: 200, body: "{}")
      stub_request(:post, url).with(headers: { "Authorization" => "Bearer token-1" }).
        to_return(status: 200, body: "{}")
      client.post(path, {})
      credentials.expire!
      client.post(path, {})

      assert_requested stub
    end

    it "raises Riffer::Error with the API message on a failing status" do
      stub_request(:post, url).to_return(status: 404, body: '{"error":{"code":404,"message":"not found"}}')
      error = expect { client.post(path, {}) }.must_raise Riffer::Error

      expect(error.message).must_equal "Google Cloud API error (404): not found"
    end

    it "raises Riffer::Error with the raw body when the error is not JSON" do
      stub_request(:post, url).to_return(status: 502, body: "bad gateway")
      error = expect { client.post(path, {}) }.must_raise Riffer::Error

      expect(error.message).must_equal "Google Cloud API error (502): bad gateway"
    end
  end

  describe "#post_stream" do
    let(:stream_path) { "publishers/google/models/gemini-2.5-flash-lite:streamGenerateContent?alt=sse" }
    let(:stream_url) { "https://aiplatform.googleapis.com/v1/projects/my-project/locations/global/#{stream_path}" }

    it "yields the response body chunks" do
      stub_request(:post, stream_url).to_return(status: 200, body: "data: {}\r\n\r\n")
      chunks = []
      client.post_stream(stream_path, {}) { |chunk| chunks << chunk }

      expect(chunks.join).must_equal "data: {}\r\n\r\n"
    end

    it "raises Riffer::Error on a failing status" do
      stub_request(:post, stream_url).to_return(status: 403, body: '{"error":{"message":"denied"}}')

      expect { client.post_stream(stream_path, {}) { |_c| } }.must_raise Riffer::Error
    end

    it "raises Riffer::Error with the API message when the error body is a JSON array" do
      claude_path = "publishers/anthropic/models/claude-haiku-4-5@20251001:streamRawPredict"
      stub_request(:post, "https://aiplatform.googleapis.com/v1/projects/my-project/locations/global/#{claude_path}").
        to_return(status: 401, body: '[{"error":{"code":401,"message":"bad token"}}]')
      error = expect { client.post_stream(claude_path, {}) { |_c| } }.must_raise Riffer::Error

      expect(error.message).must_equal "Google Cloud API error (401): bad token"
    end
  end

  describe "concurrent token refresh" do
    let(:credentials) { credentials_class.new(refresh_delay: 0.05) }

    it "shares one refresh across fibers that need a token at the same time" do
      stub_request(:post, url).to_return(status: 200, body: "{}")
      clients = Array.new(5) do
        Riffer::Providers::GoogleCloud::Client.new(project_id: "my-project", location: "global",
                                                   credentials: credentials,)
      end

      Sync do
        barrier = Async::Barrier.new
        clients.each { |c| barrier.async { c.post(path, {}) } }
        barrier.wait
      end

      expect(credentials.refreshes).must_equal 1
      assert_requested :post, url, headers: { "Authorization" => "Bearer token-1" }, times: 5
    end
  end
end
