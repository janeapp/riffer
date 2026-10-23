# frozen_string_literal: true

require "test_helper"
require "async"
require "async/barrier"
require "googleauth"

describe Riffer::Providers::GoogleCloud::Client do
  # Mimics googleauth's BaseClient#updater_proc: refreshes only a missing
  # token, and the refresh yields to the scheduler like a real metadata-server
  # call.
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

      def updater_proc
        proc do |hash|
          if @token.nil?
            sleep @refresh_delay
            @refreshes += 1
            @token = "token-#{@refreshes}"
          end
          hash.merge(authorization: "Bearer #{@token}")
        end
      end
    end
  end

  let(:credentials) { credentials_class.new }
  let(:client) do
    Riffer::Providers::GoogleCloud::Client.new(project_id: "my-project", location: "global", credentials: credentials)
  end
  let(:path) { "publishers/google/models/gemini-3.5-flash-lite:generateContent" }
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

  describe ".from_config" do
    let(:config) { Riffer::Config::GoogleCloud.new }

    it "builds a client for the configured project, location and credentials" do
      config.project_id = "my-project"
      config.location = "europe-west4"
      config.credentials = credentials
      stub = stub_request(
        :post,
        "https://europe-west4-aiplatform.googleapis.com/v1/projects/my-project/locations/europe-west4/#{path}",
      ).with(headers: { "Authorization" => "Bearer token-1" }).to_return(status: 200, body: "{}")
      Riffer::Providers::GoogleCloud::Client.from_config(config).post(path, {})

      assert_requested stub
    end

    it "raises when no project id is configured" do
      error = expect { Riffer::Providers::GoogleCloud::Client.from_config(config) }.must_raise Riffer::ArgumentError

      expect(error.message).must_equal "Riffer.config.google_cloud.project_id must be set"
    end
  end

  describe "#initialize" do
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

    it "sends the token of credentials whose apply! returns the headers hash" do
      key = {
        type: "service_account",
        private_key: OpenSSL::PKey::RSA.new(2048).to_pem,
        client_email: "riffer@my-project.iam.gserviceaccount.com",
      }
      self_signed = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(key.to_json),
        scope: Riffer::Providers::GoogleCloud::Client::SCOPE,
        enable_self_signed_jwt: true,
      )
      stub = stub_request(:post, url).with(headers: { "Authorization" => /\ABearer ey/ }).
        to_return(status: 200, body: "{}")
      Riffer::Providers::GoogleCloud::Client.new(
        project_id: "my-project", location: "global", credentials: self_signed,
      ).post(path, {})

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

    it "ignores a trailing slash on base_url" do
      stub = stub_request(:post, "http://localhost:8080/v1/projects/my-project/locations/global/#{path}").
        to_return(status: 200, body: "{}")
      custom = Riffer::Providers::GoogleCloud::Client.new(
        project_id: "my-project", location: "global", credentials: credentials, base_url: "http://localhost:8080/",
      )
      custom.post(path, {})

      assert_requested stub
    end

    it "sends requests through the given connection" do
      stub = stub_request(:post, url).with(headers: { "X-Custom" => "yes" }).to_return(status: 200, body: "{}")
      connection = Faraday.new(headers: { "X-Custom" => "yes" })
      custom = Riffer::Providers::GoogleCloud::Client.new(
        project_id: "my-project", location: "global", credentials: credentials, connection: connection,
      )
      custom.post(path, {})

      assert_requested stub
    end

    it "sends the passed headers alongside the token" do
      stub = stub_request(:post, url).
        with(headers: { "Authorization" => "Bearer token-1", "X-Goog-User-Project" => "billing-project" }).
        to_return(status: 200, body: "{}")
      custom = Riffer::Providers::GoogleCloud::Client.new(
        project_id: "my-project", location: "global", credentials: credentials,
        headers: { "x-goog-user-project" => "billing-project" },
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

    it "raises Riffer::APIError with the status and API message on a failing status" do
      body = '{"error":{"code":404,"message":"not found"}}'
      stub_request(:post, url).to_return(status: 404, body: body)
      error = expect { client.post(path, {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Google Cloud API error (404): not found"
      expect(error.status).must_equal 404
      expect(error.body).must_equal body
    end

    it "raises Riffer::APIError with the raw body when the error is not JSON" do
      stub_request(:post, url).to_return(status: 502, body: "bad gateway")
      error = expect { client.post(path, {}) }.must_raise Riffer::APIError

      expect(error.message).must_equal "Google Cloud API error (502): bad gateway"
    end
  end

  describe "#post_stream" do
    let(:stream_path) { "publishers/google/models/gemini-3.5-flash-lite:streamGenerateContent?alt=sse" }
    let(:stream_url) { "https://aiplatform.googleapis.com/v1/projects/my-project/locations/global/#{stream_path}" }

    it "yields the response body chunks" do
      stub_request(:post, stream_url).to_return(status: 200, body: "data: {}\r\n\r\n")
      chunks = []
      client.post_stream(stream_path, {}) { |chunk| chunks << chunk }

      expect(chunks.join).must_equal "data: {}\r\n\r\n"
    end

    it "raises Riffer::APIError on a failing status without yielding the body" do
      stub_request(:post, stream_url).to_return(status: 403, body: '{"error":{"message":"denied"}}')
      chunks = []
      error = expect { client.post_stream(stream_path, {}) { |chunk| chunks << chunk } }.must_raise Riffer::APIError

      expect(error.status).must_equal 403
      expect(chunks).must_be_empty
    end

    it "raises Riffer::APIError with the API message when the error body is a JSON array" do
      stub_request(:post, stream_url).to_return(status: 401, body: '[{"error":{"code":401,"message":"bad token"}}]')
      error = expect { client.post_stream(stream_path, {}) { |_c| } }.must_raise Riffer::APIError

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
